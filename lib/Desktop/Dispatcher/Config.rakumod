
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
#has Hash $!image-map;

#-------------------------------------------------------------------------------
submethod BUILD ( Str :$!config-directory is copy ) {

  $!config-directory = ?$!config-directory ?? $!config-directory !! DATA_DIR;

  die "configuration directory not found" unless $!config-directory.IO.d;

  mkdir DATA_DIR ~ '/Images', 0o700 unless (DATA_DIR ~ '/Images').IO.e;
  
  my Str $png-file;
  for <
    diamond-steel-floor.jpg brushed-light.jpg brushed-dark.jpg
    config-icon.jpg brushed-copper.jpg mozaic.jpg dispatch-icon.png
  > -> $i {
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
method load-config ( ) {
  $!dispatch-config = load-yaml(
    "$!config-directory/dispatch-config.yaml".IO.slurp
  );

  die "dispatch configuration not found" unless ?$!dispatch-config;

  # Check for exernal defined session parts
  for $!dispatch-config<sessions>.keys -> $session {
    if $!dispatch-config<sessions>{$session} ~~ Array {
      my Str ( $file, $name ) = | $!dispatch-config<sessions>{$session};
      $file = self.set-path("$*parts/$file");
      my Hash $part-cfg = load-yaml($file.IO.slurp);
      if $part-cfg<sessions>{$name}:exists {
        $!dispatch-config<sessions>{$session} =
          $part-cfg<sessions>{$name}:delete;
      }
    }
  }
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
method set-path ( Str $file = '' --> Str ) {
  my Str $path = ($file.index('/') // -1) == 0
                  ?? $file
                  !! [~] $!config-directory, '/', $file;

  note "Set icon to $path" if $*verbose;

  $path
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
method get-temp-variables ( --> Hash ) {
#note "$?LINE get-vars";
  $!dispatch-config<config><temp-variables> // %();
}

#-------------------------------------------------------------------------------
method set-temp-variables ( Hash $vars ) {
#note "$?LINE get-vars";
  $!dispatch-config<config><temp-variables> = $vars
}

#-------------------------------------------------------------------------------
method get-session-title ( Str $name --> Str ) {
  $!dispatch-config<sessions>{$name}<title> // '[-]'
}

#-------------------------------------------------------------------------------
method get-session-icon ( Str $name --> Str ) {
  $!dispatch-config<sessions>{$name}<icon> // "$*images/$name/0.png"
}

#-------------------------------------------------------------------------------
method get-session-overlay-icon ( Str $name --> Str ) {
#note "$?LINE $name ", $!dispatch-config<sessions>{$name}<over> // "$*images/$name/o0.png";
  $!dispatch-config<sessions>{$name}<over> // "$*images/$name/o0.png"
}

#-------------------------------------------------------------------------------
method get-session-actions ( Str $name, Int :$level = 0 --> List ) {
  @($!dispatch-config<sessions>{$name}{
    'actions' ~ ($level <= 0 ?? '' !! $level.Str)
  })
}

#-------------------------------------------------------------------------------
method has-actions-level ( Str $name, Int :$level = 0 --> Bool ) {
  $!dispatch-config<sessions>{$name}{
    'actions' ~ ($level <= 0 ?? '' !! $level.Str)
  }:exists
}

#-------------------------------------------------------------------------------
method get-toolbar-actions ( --> List ) {
  $!dispatch-config<toolbar>:exists ?? @($!dispatch-config<toolbar>) !! ()
}

#-------------------------------------------------------------------------------
method get-shell ( --> Str ) {
  $!dispatch-config<shell>:exists ?? $!dispatch-config<shell> !! '/usr/bin/bash'
}
