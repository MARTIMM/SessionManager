use v6.d;

use SessionManager::Gui::Variables;
use SessionManager::ActionData;
use SessionManager::Gui::Actions;

use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::T-styleprovider:api<2>;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use YAMLish;
use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class SessionManager::Config;

#-------------------------------------------------------------------------------
my $instance;

constant APP_ID is export = 'io.github.martimm.session-manager';

has Bool $.legacy = False;

has Hash $!dispatch-config;
has Gnome::Gtk4::CssProvider $!css-provider;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$*config-directory ) {
#  $!action-refs = %();
#  $!variables = %();
#note "$?LINE $*config-directory";

  mkdir $*config-directory ~ '/Images', 0o700
        unless ($*config-directory ~ '/Images').IO.e;
  
  # It is supposed to copy files to a controllable location See also issue #5746
  # at https://github.com/rakudo/rakudo/issues/5746.
  my Str $png-file;
  for <
    diamond-steel-floor.jpg brushed-light.jpg brushed-dark.jpg
    config-icon.jpg brushed-copper.jpg mozaic.jpg dispatch-icon.png
    bookmark.png fastforward.png
  > -> $i {

  # Are used in the css file and must be accessable in a known path. Rest can
  # be retrieved from the resources.
#  for <
#    brushed-dark.jpg brushed-copper.jpg
#  > -> $i {
    $png-file = [~] $*config-directory, '/Images/', $i;
    %?RESOURCES{$i}.copy($png-file) unless $png-file.IO.e;
  }

  # Copy style sheet to data directory and load into program
  my Str $css-file = $*config-directory ~ '/Config/manager.css';
  %?RESOURCES<manager.css>.copy($css-file);
  my $css-cnt = [~] '@import url("', $css-file, '")', "\n\n",
                    %?RESOURCES<manager-changes.css>.slurp;
  $css-file = $*config-directory ~ '/Config/manager-changes.css';
  $css-file.IO.spurt($css-cnt);
note $css-cnt;
  $!css-provider .= new-cssprovider;
  $!css-provider.load-from-path($css-file);

  self.load-config;
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance (
  Str :$config-directory --> SessionManager::Config
) {
  $instance //= self.bless(:$config-directory);

  $instance
}

#-------------------------------------------------------------------------------
method load-config ( ) {
  $!dispatch-config = load-yaml(
    "$*config-directory/dispatch-config.yaml".IO.slurp
  );

  die "dispatch configuration not found" unless ?$!dispatch-config;

  $*images = [~] $*config-directory, '/', $*images;

  # Set a few variables beforehand
  my SessionManager::Gui::Variables $variables .= instance;
  $variables.add( %(
    :$*config-directory,
    :home($*HOME),
  ));

  # First! Check and load variables
  if $!dispatch-config<variable-references>:exists {
    for @($!dispatch-config<variable-references>) -> $file is copy {
      $file = $variables.substitute-vars($file);
      $variables.add-from-yaml($file);
    }
  }

  $variables.save;

  # Check and load separate session descriptions, variables are now possible
  if $!dispatch-config<part-references>:exists {
    my Hash $ref := $!dispatch-config<part-references>;
    for $ref.kv -> $name, $file is copy {
      $file = $variables.substitute-vars($file);
      $!dispatch-config<sessions>{$name} = load-yaml($file.IO.slurp);
    }
  }

  # Check and load separate action descriptions
  if $!dispatch-config<action-references>:exists {
    my SessionManager::Gui::Actions $actions .= instance;
    for @($!dispatch-config<action-references>) -> $file is copy {
      $file = $variables.substitute-vars($file);
      $actions.add-from-yaml($file);
    }

    $actions.save;
  }


  self.check-actions;
}

#-------------------------------------------------------------------------------
method check-actions ( ) {
#note "$?LINE $name, $level, $!dispatch-config<sessions>{$name}.gist()";
#  CONTROL { when CX::Warn {  note .gist; .resume; } }
#  CATCH { default { .message.note; .backtrace.concise.note } }

#  $!dispatch-config<toolbar> =
#    self.check-session-entries($!dispatch-config<toolbar>);

  for $!dispatch-config<sessions>.keys -> $name {
    my Hash $sessions = $!dispatch-config<sessions>{$name};
    for 1 .. 10 -> $level {
      last unless $sessions{'group' ~ $level}<actions>:exists;
      $sessions{'group' ~ $level}<actions> =
        self.check-session-entries($sessions{'group' ~ $level}<actions>);
    }
  }
}

#-------------------------------------------------------------------------------
method check-session-entries ( Array $raw-entries --> Array ) {
  my SessionManager::Gui::Actions $actions .= instance;

  # It is possible that an entry is just a string. If so, the string is
  # a key in the $!action-refs hash to get the action hash from there.
  # When it is a Hash, it must be added to the actions data
  for 0 ..^ $raw-entries.elems -> $i {
    if $raw-entries[$i] ~~ Hash {
      # Add the actions Hash to the action data and
      # store the returned id instead.
      $raw-entries[$i] = $actions.add-action($raw-entries[$i]);
    }
  }
  
  $raw-entries
}

#-------------------------------------------------------------------------------
method set-css ( N-Object $context, Str:D $css-class ) {
  return unless ?$css-class;

  my Gnome::Gtk4::StyleContext $style-context .= new(:native-object($context));
  $style-context.add-provider(
    $!css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $style-context.add-class($css-class);
}

#-------------------------------------------------------------------------------
method set-legacy ( Bool $!legacy ) { }

#-------------------------------------------------------------------------------
method get-window-size ( --> List ) {
  | $!dispatch-config<theme><window-size>;
}

#-------------------------------------------------------------------------------
method get-log-window-size ( --> List ) {
  | $!dispatch-config<theme><log-window-size>;
}

#-------------------------------------------------------------------------------
method get-icon-size ( --> List ) {
  | $!dispatch-config<theme><icon-size>;
}

#-------------------------------------------------------------------------------
method get-window-title ( --> Str ) {
  $!dispatch-config<theme><title> // 'Session Manager';
}

#-------------------------------------------------------------------------------
method get-sessions ( --> Hash ) {
  $!dispatch-config<sessions> // %()
}

#-------------------------------------------------------------------------------
method set-path ( Str $file = '' --> Str ) {
#note "$?LINE $file, $file.index('/')";
  my Str $path = ($file.index('/') // -1) == 0
                  ?? $file
                  !! [~] $*config-directory, '/', $file;

  note "Set icon to $path" if $*verbose;

  $path
}

=finish

#-------------------------------------------------------------------------------
method get-session-title ( Str $name --> Str ) {
  $!dispatch-config<sessions>{$name}<title> // '[-]'
}



#-------------------------------------------------------------------------------
method get-variables ( --> Hash ) {
  $!variables // %()
}

#-------------------------------------------------------------------------------
method get-temp-variables ( --> Hash ) {
  $!dispatch-config<config><temp-variables> // %();
}

#-------------------------------------------------------------------------------
method set-temp-variables ( Hash $vars ) {
  $!dispatch-config<config><temp-variables> = $vars
}

#-------------------------------------------------------------------------------
method run-all-actions ( Str $name --> Bool ) {
  $!dispatch-config<sessions>{$name}<run-all-actions> // False
}

#-------------------------------------------------------------------------------
method get-session-icon ( Str $name --> Str ) {
  $!dispatch-config<sessions>{$name}<icon> // "$*images/$name/0.png"
}

#-------------------------------------------------------------------------------
method get-session-overlay-icon ( Str $name --> Str ) {
  $!dispatch-config<sessions>{$name}<over> // "$*images/$name/o0.png"
}

#-------------------------------------------------------------------------------
method get-session-group-title ( Str $name, Int $level --> Str ) {
  $!dispatch-config<sessions>{$name}{'group' ~ $level}<title> // ''
}

#-------------------------------------------------------------------------------
method get-session-actions ( Str $name, Int $level --> List ) {
  my Hash $sessions := $!dispatch-config<sessions>{$name};
  $sessions{'group' ~ $level}<actions>:exists
      ?? | $sessions{'group' ~ $level}<actions>
      !! ()
}

#-------------------------------------------------------------------------------
method has-actions-level ( Str $name, Int $level --> Bool ) {
  $!dispatch-config<sessions>{$name}{'group' ~ $level}<actions>:exists
}

#-------------------------------------------------------------------------------
method get-toolbar-actions ( --> List ) {
  $!dispatch-config<toolbar>:exists ?? @($!dispatch-config<toolbar>) !! ()
}

#-------------------------------------------------------------------------------
method get-shell ( --> Str ) {
  $!dispatch-config<shell>:exists ?? $!dispatch-config<shell> !! '/usr/bin/bash'
}
