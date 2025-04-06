use v6.d;

use Desktop::Dispatcher::Variables;
use Desktop::Dispatcher::Actions;

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
  Str :$!config-directory --> Desktop::Dispatcher::Config
) {
  $instance //= self.bless(:$!config-directory);

  $instance
}

#-------------------------------------------------------------------------------
method load-config ( ) {
  $!dispatch-config = load-yaml(
    "$!config-directory/dispatch-config.yaml".IO.slurp
  );

  die "dispatch configuration not found" unless ?$!dispatch-config;

  # Check and load separate session descriptions
  if $!dispatch-config<part-references>:exists {
    my Hash $ref := $!dispatch-config<part-references>;
    for $ref.kv -> $name, $file {
      $!dispatch-config<sessions>{$name} = load-yaml($file.IO.slurp);
    }
  }

  # Check and load separate action descriptions
  if $!dispatch-config<action-references>:exists {
    my Desktop::Dispatcher::Actions $actions .= new;
    for @($!dispatch-config<action-references>) -> $file {
#      $!action-refs = %( | $!action-refs, | load-yaml($file.IO.slurp));
#note "$?LINE thunderbird: {$!action-refs<thunderbird-o>//'-'}";
#note "$?LINE : {$!action-refs<thunderbird-o>//'-'}";
      $!action-refs =
        self.merge-hash( $!action-refs, load-yaml($file.IO.slurp));
    }
  }

  # Check and load variables
  if $!dispatch-config<variable-references>:exists {
    for @($!dispatch-config<variable-references>) -> $file {
      $!variables = %( | $!variables, | load-yaml($file.IO.slurp));
    }
  }

  self.change-session-actions;

#note "\n\n$?LINE $!action-refs<puzzletable-run>.gist()";
#note "\n$?LINE $!variables.gist()";
}
