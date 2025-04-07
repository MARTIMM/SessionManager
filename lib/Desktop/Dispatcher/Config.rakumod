use v6.d;

use Desktop::Dispatcher::Variables;
use Desktop::Dispatcher::ActionData;
use Desktop::Dispatcher::Actions;

use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::T-styleprovider:api<2>;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use YAMLish;
use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Config;

#-------------------------------------------------------------------------------
my $instance;

constant APP_ID is export = 'io.github.martimm.dispatcher';
constant DATA_DIR is export = [~] $*HOME, '/.config/', APP_ID;

has Str $.config-directory;
#has Hash $!action-refs;
#has Hash $!variables;

has Hash $!dispatch-config;
has Gnome::Gtk4::CssProvider $!css-provider;
#has Hash $!image-map;

#-------------------------------------------------------------------------------
submethod BUILD ( Str :$!config-directory = DATA_DIR ) {
#  $!action-refs = %();
#  $!variables = %();

  die "configuration directory not found" unless $!config-directory.IO.d;

  mkdir DATA_DIR ~ '/Images', 0o700 unless (DATA_DIR ~ '/Images').IO.e;
  
  my Str $png-file;
# It is supposed to copy files to a controllable location See also issue #5746
# at https://github.com/rakudo/rakudo/issues/5746.
# But this can be done: %?RESOURCES<dispatcher.css>.IO.absolute()
# !!!It is warned against doing this!!!
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
    $png-file = [~] DATA_DIR, '/Images/', $i;
    %?RESOURCES{$i}.copy($png-file) unless $png-file.IO.e;
  }
  # Copy style sheet to data directory and load into program
  my Str $css-file = DATA_DIR ~ '/dispatcher.css';
  %?RESOURCES<dispatcher.css>.copy($css-file);
  $css-file = DATA_DIR ~ '/dispatcher-changes.css';
  %?RESOURCES<dispatcher-changes.css>.copy($css-file);

  $!css-provider .= new-cssprovider;
  $!css-provider.load-from-path($css-file);

  self.load-config;
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance (
  Str :$config-directory --> Desktop::Dispatcher::Config
) {
  $instance //= self.bless(:$config-directory);

  $instance
}

#-------------------------------------------------------------------------------
method load-config ( ) {
  $!dispatch-config = load-yaml(
    "$!config-directory/dispatch-config.yaml".IO.slurp
  );

  die "dispatch configuration not found" unless ?$!dispatch-config;

  # Set a few variable before hand
  my Desktop::Dispatcher::Variables $variables .= instance;
  $variables.add( %(
    :$!config-directory,
    :home($*HOME),
  ));

  # First! Check and load variables
  if $!dispatch-config<variable-references>:exists {
    for @($!dispatch-config<variable-references>) -> $file {
      $variables.add-from-yaml($file);
    }
  }

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
    my Desktop::Dispatcher::Actions $actions .= instance;
    for @($!dispatch-config<action-references>) -> $file is copy {
      $file = $variables.substitute-vars($file);
      $actions.add-from-yaml($file);
    }
  }

  self.check-actions;
}

#-------------------------------------------------------------------------------
method check-actions ( ) {
#note "$?LINE $name, $level, $!dispatch-config<sessions>{$name}.gist()";
#  CONTROL { when CX::Warn {  note .gist; .resume; } }
#  CATCH { default { .message.note; .backtrace.concise.note } }

  $!dispatch-config<toolbar> =
    self.check-session-entries($!dispatch-config<toolbar>);

  for $!dispatch-config<sessions>.keys -> $name {
    my Hash $sessions = $!dispatch-config<sessions>{$name};
    for 1 .. 10 -> $level {
      last unless $sessions{'group' ~ $level}:exists;
      $sessions{'group' ~ $level}<actions> =
        self.check-session-entries($sessions{'group' ~ $level}<actions>);
    }
  }
}

#-------------------------------------------------------------------------------
method check-session-entries ( Array $raw-entries --> Array ) {
  my Desktop::Dispatcher::Actions $actions .= instance;

  # It is possible that an entry is just a string. If so, the string is
  # a key in the $!action-refs hash to get the action hash from there.
  # When it is a Hash, it must be added to the actions data
  for 0 ..^ $raw-entries.elems -> $i {
    if $raw-entries[$i] ~~ Hash and $raw-entries[$i]<t>:exists {
      $actions.add-action($raw-entries[$i]);
      $raw-entries[$i] = sha256-hex($raw-entries[$i]<t>);
    }
#TODO ... what to do when tooltip isn't there
  }
}
