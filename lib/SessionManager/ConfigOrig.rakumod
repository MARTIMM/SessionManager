
use YAMLish;

use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::T-styleprovider:api<2>;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class SessionManager::ConfigOrig:auth<github:MARTIMM>;

constant APP_ID is export = 'io.github.martimm.dispatcher';
constant DATA_DIR is export = [~] $*HOME, '/.config/', APP_ID;

has Str $.config-directory;
has Hash $!action-refs;
has Hash $!variables;

has Hash $!dispatch-config;
has Gnome::Gtk4::CssProvider $!css-provider;
#has Hash $!image-map;

#-------------------------------------------------------------------------------
submethod BUILD ( Str :$!config-directory is copy ) {
  $!action-refs = %();
  $!variables = %();

  $!config-directory = ?$!config-directory ?? $!config-directory !! DATA_DIR;

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

#-------------------------------------------------------------------------------
method merge-hash ( Hash $h1, Hash $h2 --> Hash ) {
  for $h2.kv -> $k, $v {
    if $h1{$k}:exists {
      given $h2{$k} {
        when Str {
          $h1{$k} = $h2{$k};
        }

        when Array {
          $h1{$k} = $h2{$k};
        }

        when Hash {
          $h1{$k} = self.merge-hash( $h1{$k}, $h2{$k});
        }
      }
    }

    else {
      $h1{$k} = $h2{$k};
    }
  }

  $h1
}

#-------------------------------------------------------------------------------
method change-session-actions ( ) {
#note "$?LINE $name, $level, $!dispatch-config<sessions>{$name}.gist()";
#  CONTROL { when CX::Warn {  note .gist; .resume; } }
#  CATCH { default { .message.note; .backtrace.concise.note } }

  my List $l = ();
  for $!dispatch-config<sessions>.keys -> $name {
    my Hash $sessions := $!dispatch-config<sessions>{$name};

    for 1 .. 10 -> $level {
      if $sessions{'group' ~ $level}<actions>:exists {
        $l = $sessions{'group' ~ $level}<actions>;

        # It is possible that an entry is just a string. If so, the string is
        # a key in the $!action-refs hash to get the action hash from there.
        for 0 ..^ $l.elems -> $i {
          if ( my $action = $l[$i] ) ~~ Str {
            $l[$i] = $!action-refs{$action};
          }
        }

        $sessions{'group' ~ $level}<actions> = $l;
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
  ($!dispatch-config<sessions> // %()).keys.sort
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
method get-session-title ( Str $name --> Str ) {
  $!dispatch-config<sessions>{$name}<title> // '[-]'
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
