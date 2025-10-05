use v6.d;

use SessionManager::Variables;
use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::ActionData;

#use Gnome::Gtk4::StyleContext:api<2>;
#use Gnome::Gtk4::CssProvider:api<2>;
#use Gnome::Gtk4::T-styleprovider:api<2>;

use GnomeTools::Gtk::Theming;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use YAMLish;
use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class SessionManager::Config;

#-------------------------------------------------------------------------------
my $instance;

has Bool $.legacy = False;

has Hash $!dispatch-config;
#has Gnome::Gtk4::CssProvider $!css-provider;

has GnomeTools::Gtk::Theming $!theme;

#-------------------------------------------------------------------------------
submethod BUILD ( Bool :$load-manual-build-config = False ) {
#note "$?LINE $*config-directory";

  mkdir $*config-directory ~ '/Images', 0o700
        unless ($*config-directory ~ '/Images').IO.e;

  # It is supposed to copy files to a controllable location See also issue #5746
  # at https://github.com/rakudo/rakudo/issues/5746.
  # Are used in the css file and must be accessable in a known path. Rest can
  # be retrieved from the resources.
  my Str $png-file;
  for <
    diamond-steel-floor.jpg brushed-light.jpg brushed-dark.jpg
    config-icon.jpg brushed-copper.jpg mozaic.jpg
    bookmark.png fastforward.png
  > -> $i {
#note "$?LINE $i";
    $png-file = [~] $*config-directory, '/Images/', $i;
    %?RESOURCES{$i}.copy($png-file) unless $png-file.IO.e;
  }

  # Copy style sheet to data directory and load into program
  my Str $css-path = $*config-directory ~ '/Config/manager.css';
  %?RESOURCES<manager.css>.copy($css-path);
  my $css-cnt = [~] '@import url("', $css-path.IO.absolute, '");', "\n\n",
                    %?RESOURCES<manager-changes.css>.slurp;
  $css-path = $*config-directory ~ '/Config/manager-changes.css';
  $css-path.IO.spurt($css-cnt);
  $!theme .= new(:$css-path);

  self.load-config(:$load-manual-build-config);
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( *%options --> SessionManager::Config ) {
  $instance //= self.bless(|%options);

  $instance
}

#-------------------------------------------------------------------------------
method load-config ( Bool :$load-manual-build-config = False ) {
  if "$*config-directory/dispatch-config.yaml".IO !~~ :r {
    "$*config-directory/dispatch-config.yaml".IO.spurt(Q:q:to/EOD/);
      theme:
        title: Environment starter

        icon-size: [ 200, 200]
        window-size: [ 1000, 200]
        log-window-size: [ 900, 1300]

      part-references: {}
      action-references: {}
      variable-references: {}
      sessions: {}
      EOD
  }

  $!dispatch-config = load-yaml(
    "$*config-directory/dispatch-config.yaml".IO.slurp
  );


  $*images = [~] $*config-directory, '/', $*images;

  my SessionManager::Variables $variables .= new;
  my SessionManager::Actions $actions .= new;
  my SessionManager::Sessions $sessions .= new;

  # Set a few variables beforehand
  if $load-manual-build-config {
    $variables.add(%( :$*config-directory, :home($*HOME)));

    # First! Check and load variables
    if $!dispatch-config<variable-references>:exists {
      for @($!dispatch-config<variable-references>) -> $file is copy {
        $file = $variables.substitute-vars($file);
        $variables.add-from-yaml($file);
      }
    }

    # Check session descriptions from config, variables are now possible
    for $!dispatch-config<sessions>.keys -> $name {
      $sessions.add-session( $name, $!dispatch-config<sessions>{$name});
    }

    # Check and load separate session descriptions
    if $!dispatch-config<part-references>:exists {
      my Hash $ref := $!dispatch-config<part-references>;
      for $ref.kv -> $name, $file is copy {
        $file = $variables.substitute-vars($file);
        $!dispatch-config<sessions>{$name} = load-yaml($file.IO.slurp);
        $sessions.load-session( $name, $file);
      }
    }

    # Check and load separate action descriptions
    if $!dispatch-config<action-references>:exists {
      for @($!dispatch-config<action-references>) -> $file is copy {
        $file = $variables.substitute-vars($file);
        $actions.add-from-yaml($file);
      }
    }
  }

  $variables.load;
  $actions.load;
  $sessions.load;

  self.check-actions;
}

#-------------------------------------------------------------------------------
method check-actions ( ) {
#note "$?LINE $name, $level, $!dispatch-config<sessions>{$name}.gist()";
#  CONTROL { when CX::Warn {  note .gist; .resume; } }
#  CATCH { default { .message.note; .backtrace.concise.note } }

#  $!dispatch-config<toolbar> =
#    self.check-session-entries($!dispatch-config<toolbar>);
  my SessionManager::Sessions $sessions .= new;

#  for $!dispatch-config<sessions>.keys -> $name {
#    my Hash $sessions = $!dispatch-config<sessions>{$name};
  for $sessions.get-session-ids -> $sid {
    my Hash $session = $sessions.get-session($sid);
    for 1 .. 10 -> $level {
      last unless $session{'group' ~ $level}<actions>:exists;
      $session{'group' ~ $level}<actions> =
        self.check-session-entries($session{'group' ~ $level}<actions>);
    }
  }
}

#-------------------------------------------------------------------------------
method check-session-entries ( Array $raw-entries --> Array ) {
  my SessionManager::Actions $actions .= new;

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

#`{{
#-------------------------------------------------------------------------------
method set-css ( N-Object $context, Str:D $css-class ) {
  return unless ?$css-class;

  my Gnome::Gtk4::StyleContext $style-context .= new(:native-object($context));
  $style-context.add-provider(
    $!css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $style-context.add-class($css-class);
}
}}

#-------------------------------------------------------------------------------
method set-legacy ( Bool $!legacy ) { }

#-------------------------------------------------------------------------------
method get-window-size ( --> List ) {
  | $!dispatch-config<theme><window-size>;
}

#-------------------------------------------------------------------------------
method set-window-size ( Int:D $w, Int:D $h ) {
  $!dispatch-config<theme><window-size>[0] = $w;
  $!dispatch-config<theme><window-size>[1] = $h;
}

#-------------------------------------------------------------------------------
method get-log-window-size ( --> List ) {
  | $!dispatch-config<theme><log-window-size>;
}

#-------------------------------------------------------------------------------
method set-log-window-size ( Int:D $w, Int:D $h ) {
  $!dispatch-config<theme><log-window-size>[0] = $w;
  $!dispatch-config<theme><log-window-size>[1] = $h;
}

#-------------------------------------------------------------------------------
method get-icon-size ( --> List ) {
  | $!dispatch-config<theme><icon-size>;
}

#-------------------------------------------------------------------------------
method set-icon-size ( Int:D $w, Int:D $h ) {
  $!dispatch-config<theme><icon-size>[0] = $w;
  $!dispatch-config<theme><icon-size>[1] = $h;
}

#-------------------------------------------------------------------------------
method get-window-title ( --> Str ) {
  $!dispatch-config<theme><title> // 'Session Manager';
}

#-------------------------------------------------------------------------------
method set-window-title ( Str:D $title ) {
  $!dispatch-config<theme><title> = $title;
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
method get-shell ( --> Str ) {
  $!dispatch-config<shell> // '/usr/bin/bash';
}

#-------------------------------------------------------------------------------
method set-shell ( Str:D $shell ) {
  $!dispatch-config<shell> = $shell;
}

#-------------------------------------------------------------------------------
method get-sessions ( --> Hash ) {
  my SessionManager::Gui::Sessions $sessions .= instance;
  $sessions.get-sessions
  #$!dispatch-config<sessions> // %()
}

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
