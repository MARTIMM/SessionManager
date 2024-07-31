
use YAMLish;

use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::T-styleprovider:api<2>;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Config:auth<github:MARTIMM>;

constant APP_ID is export = 'io.github.martimm.dispatcher';
constant DATA_DIR is export = [~] $*HOME, '/.config/', APP_ID;

has Str $.config-directory;
has Hash $!dispatch-config;
has Gnome::Gtk4::CssProvider $!css-provider;

#-------------------------------------------------------------------------------
submethod BUILD ( Str :$!config-directory is copy ) {

  $!config-directory = ?$!config-directory ?? $!config-directory !! DATA_DIR;

  die "configuration directory not found" unless $!config-directory.IO.d;

  mkdir DATA_DIR ~ '/Images', 0o700 unless (DATA_DIR ~ '/Images').IO.e;
  
  my Str $png-file;
  for <
    diamond-steel-floor.jpg brushed-light.jpg brushed-dark.jpg
    config-icon.jpg brushed-copper.jpg mozaic.jpg
  > -> $i {
    $png-file = [~] DATA_DIR, '/Images/', $i;
    %?RESOURCES{$i}.copy($png-file) unless $png-file.IO.e;
  }

  # Copy style sheet to data directory and load into program
  my Str $css-file = DATA_DIR ~ '/dispatcher.css';
  %?RESOURCES<dispatcher.css>.copy($css-file);
  $css-file = DATA_DIR ~ '/dispatcher-changes.css';
  %?RESOURCES<dispatcher-changes.css>.copy($css-file);
#note "$?LINE $css-file";

  $!css-provider .= new-cssprovider;
  $!css-provider.load-from-path($css-file);

  self.load-config;
}

#-------------------------------------------------------------------------------
method load-config ( ) {
  $!dispatch-config = load-yaml(
    "$!config-directory/dispatch-config.yaml".IO.slurp
  );

#note "$?LINE load, $!dispatch-config.gist()";
  die "dispatch configuration not found" unless ?$!dispatch-config;

  $*dispatch-testing = $!dispatch-config<config><dispatch-testing> // True;
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
method get-window-title ( --> Str ) {
  $!dispatch-config<theme><title> // 'Dispatcher';
}

#-------------------------------------------------------------------------------
method get-window-size ( --> List ) {
  | $!dispatch-config<theme><window-size>;
}

#-------------------------------------------------------------------------------
method get-icon-size ( --> List ) {
  | $!dispatch-config<theme><icon-size>;
}

#-------------------------------------------------------------------------------
method get-sessions ( --> Seq ) {
#note "$?LINE get-actions";
  ($!dispatch-config<sessions> // %()).keys.sort
}

#-------------------------------------------------------------------------------
method get-variables ( --> Hash ) {
#note "$?LINE get-vars";
  $!dispatch-config<config><variables> // %()
}

#-------------------------------------------------------------------------------
method get-session-title ( Str $name --> Str ) {
  $!dispatch-config<sessions>{$name}<title> // '[-]'
}

#-------------------------------------------------------------------------------
# Use: for $x.get-session-action($n) -> $action { }
method get-session-action( Str $name --> Seq ) {
  gather for @($!dispatch-config<sessions>{$name}<actions>) -> $action {
    take $action;
  }
}
