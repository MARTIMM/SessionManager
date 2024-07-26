
use v6.d;

use NativeCall;

use Desktop::Dispatcher::Config;
use Desktop::Dispatcher::Actions;

use YAMLish;
use Getopt::Long;

use Gnome::Gtk4::CssProvider:api<2>;
use Gnome::Gtk4::StyleContext:api<2>;
use Gnome::Gtk4::T-styleprovider:api<2>;

use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Application:api<2>;

use Gnome::Gio::ApplicationCommandLine:api<2>;
use Gnome::Gio::SimpleAction:api<2>;
use Gnome::Gio::T-ioenums:api<2>;

use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Application:auth<github:MARTIMM>;

has Gnome::Gtk4::Application $!application;
has Gnome::Gtk4::ApplicationWindow $!app-window;

has Desktop::Dispatcher::Config $!config;
#has Desktop::Dispatcher::Actions $!actions;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
# $!dispatch-testing = True;

  $!application .= new-application(
    APP_ID, G_APPLICATION_HANDLES_COMMAND_LINE
  );

  # Register all necessary signals
  $!application.register-signal( self, 'app-activate', 'activate');
  $!application.register-signal( self, 'local-options', 'handle-local-options');
  $!application.register-signal( self, 'remote-options', 'command-line');
  $!application.register-signal( self, 'startup', 'startup');
  $!application.register-signal( self, 'shutdown', 'shutdown');

  # Save when an interrupt arrives
  signal(SIGINT).tap( {
      exit 0;
    }
  );

  # Now we can register the application.
  my $e = CArray[N-Error].new(N-Error);
  $!application.register( N-Object, $e);
  die $e[0].message if ?$e[0];
}

#-------------------------------------------------------------------------------
method go-ahead ( --> Int ) {
  my Int $argc = 1 + @*ARGS.elems;

  my $arg_arr = CArray[Str].new();
  $arg_arr[0] = $*PROGRAM.Str;
  my Int $arg-count = 1;
  for @*ARGS -> $arg {
    $arg_arr[$arg-count++] = $arg;
  }

  my $argv = CArray[Str].new($arg_arr);

  $!application.run( $argc, $argv);
}

#-------------------------------------------------------------------------------
method local-options ( N-Object $no-vd --> Int ) {
  # By default, continue to proces remote options and/or activation of
  # primary instance
  my Int $exit-code = -1;

  CATCH { default { .message.note; $exit-code = 1; return $exit-code; } }

  # Local options which do not need a config file or primary instance
  my $o = get-options( |$*local-options, |$*remote-options);
  if $o<version> {
    say "Version of dispatcher is $*dispatcher-version";
    $exit-code = 0;
  }

  $exit-code
}

#-------------------------------------------------------------------------------
method remote-options ( Gnome::Gio::ApplicationCommandLine() $cl --> Int ) {

  my Array $cmd-list = [];

  my Array $args = $cl.get-arguments;
  my Capture $o = get-options-from( $args[1..*-1], |$*remote-options);

  my Str $config-directory;
  if ?$o<config> {
    $config-directory = $o.<config> // Str;
  }

  $!config .= new(:$config-directory);
  #$!config.load-config;

  if $cl.get-is-remote {
    self.setup-window;
  }

  else {
    $!application.activate;
  }

  $cl.done;
  $cl.clear-object;
  0
}

#-------------------------------------------------------------------------------
#-- [callback handlers] --------------------------------------------------------
#-------------------------------------------------------------------------------
# Called after registration of the application
method startup ( ) {
}

#-------------------------------------------------------------------------------
# Activation of the application takes place when processing remote options
# reach the default entry, or when setup options are processed.
# And when this process is also the primary instance, it's only called once
# because we don't need to create two gui's. This is completely automatically
# done.
method app-activate ( ) {
#`{{
  # Place grid in a scrollable window so we can move it up and down
  with my Gnome::Gtk4::ScrolledWindow $swin .= new-scrolledwindow {
#    .set-child($!groups-grid);
  }

  # Set the theme and initialize application window and give this object (a
  # Gnome::Gtk4::Application) as its argument.
  with $!app-window .= new-applicationwindow($!application) {
    my Desktop::Dispatcher::Actions $actions .= new(:$!config);
    $actions.setup-sessions(:container($swin));

    .set-child($swin);

#    .set-size-request($!config.get-window-size);
    .set-title($!config.get-window-title);

    .show;
  }
}}
  self.setup-window;
}

#-------------------------------------------------------------------------------
method setup-window ( ) {

  # Set the theme and initialize application window and give this object (a
  # Gnome::Gtk4::Application) as its argument.
  if ?$!app-window and $!app-window.is-valid {
    $!application.remove-window($!app-window);
    $!app-window.destroy;
    $!app-window.clear-object;
  }

  # Place grid in a scrollable window so we can move it up and down
#  my Gnome::Gtk4::ScrolledWindow $swin .= new-scrolledwindow;

  with $!app-window .= new-applicationwindow($!application) {
    my Desktop::Dispatcher::Actions $actions .= new(:$!config);
    my Gnome::Gtk4::ScrolledWindow $swin = $actions.setup-sessions;

    .set-child($swin);
    .set-title($!config.get-window-title);

    .show;
  }
}

#-------------------------------------------------------------------------------
# Handled after pressing the close button added by the desktop manager
method exit-program ( ) {
  self.quit;
}

#-------------------------------------------------------------------------------
method shutdown ( ) {
  # save changed config?
}













=finish

#`{{
#-------------------------------------------------------------------------------
method get-group-config ( Str:D $group --> Hash ) {

#note $!dispatch-config.gist;

  my Hash $group-cfg = $!dispatch-config<action-groups>;
  my Array $actions-group = [$group.split('/')];

  for @$actions-group -> $ap {
    if $group-cfg{$ap}:exists and $group-cfg{$ap} ~~ Hash {
      $group-cfg = $group-cfg{$ap};
    }

    else {
      note "group '$group', not found";
      $group-cfg = Hash;
      last;
    }
  }

  $group-cfg
}

#-------------------------------------------------------------------------------
method get-actions (
  Hash:D $group-config, Str $group, Str:D $actions --> Array
) {
  my Hash $group-cfg = $group-config<actions>;
  my Array $cmd-list = [];

  my Array $as = [$actions.split(',')];
  for @$as -> $a {
    if $group-cfg{$a}:exists {
      my $cmd = self.make-command( $a, $group-cfg{$a});
      if !$cmd {
        $cmd-list = [];
        last;
      }

      $cmd-list.push: $cmd;
    }

    else {
      note "action '$a', not found in group '$group'";
      $cmd-list = [];
      last;
    }
  }

  $cmd-list
}

#-------------------------------------------------------------------------------
method get-all-actions ( Hash:D $group-config --> Array ) {

  my Hash $group-cfg = $group-config<actions>;
  my Array $cmd-list = [];

  for $group-cfg.keys -> $a {
    my $cmd = self.make-command( $a, $group-cfg{$a});
    if !$cmd {
      $cmd-list = [];
      last;
    }

    $cmd-list.push: $cmd;
  }

  $cmd-list
}

#-------------------------------------------------------------------------------
method dispatch ( Array:D $cmd-list --> Bool ) {

  if !$cmd-list {
    note "Due to errors, actions are not executed";
    return False;
  }

  if $*dispatch-testing {
    note "\nTest mode is turned on; show commands only";
  }

  else {
    note "\nTest mode is turned off; next commands are executed";
  }

  for @$cmd-list -> $cmd {
    note "execute: '$cmd'";
    my Proc $proc = shell "$cmd &" unless $*dispatch-testing;
  }

  ?$cmd-list
}

#-------------------------------------------------------------------------------
method make-command ( Str $action, Hash $cmd-cfg --> Str ) {
#note "\naction: $cmd-cfg.gist()";

  # Can be a command or a large piece of text
  my Str $cmd = '';
  if $cmd-cfg<command> {
    $cmd = $cmd-cfg<command>;
    $cmd ~~ s:g/\s+/ /;
    $cmd ~~ s/\s+ $//;

    if $cmd ~~ m/^ [rm || mv || cp] \s / {
      note "command is inherently dangerous to execute from here - ignored";
      note "You still can shoot yourself in the foot, see https://www.tecmint.com/10-most-dangerous-commands-you-should-never-execute-on-linux/";
      $cmd = '';
    }
  }

  else {
    note "no command found to execute for this action '$action'";
  }

  $cmd
}
}}

#`{{
#-----------------------------------------------------------------------------
method !link-menu-action ( Str :$action, Str :$method is copy, Str :$state ) {

  $method //= $action;

  my Gnome::Gio::SimpleAction $menu-entry;
  if ?$state {
    $menu-entry .= new(
      :name($action),
      :parameter-type(Gnome::Glib::VariantType.new(:type-string<s>)),
      :state(Gnome::Glib::Variant.new(:parse("'$state'")))
    );
    $menu-entry.register-signal( self, $method, 'change-state');
  }

  else {
    $menu-entry .= new(
      :name($action),
#        :parameter-type(Gnome::Glib::VariantType.new(:type-string<s>))
    );
    $menu-entry.register-signal( self, $method, 'activate');
  }

  self.add-action($menu-entry);

  #cannot clear -> need to use it in handler!
  $menu-entry.clear-object;
}
}}

#`{{
#-------------------------------------------------------------------------------
method !set-groups-in-grid ( ) {
  my Int $group-count = 0;
  for $!dispatch-config<action-groups>.keys.sort -> $kg {
#note $!dispatch-config<action-groups>{$kg}.keys.gist;

    my Int $set-count = 0;
    my Grid $set-grid .= new-grid;
    for $!dispatch-config<action-groups>{$kg}.keys.sort -> $ks {
      with my Button $sbutton .= new-button {
#        .set-always-show-image(True);
        .set-tooltip-text(
          $!dispatch-config<action-groups>{$kg}{$ks}<title> // $ks
        );

        my Str $icon = $!dispatch-config<action-groups>{$kg}{$ks}<icon> //
                       %?RESOURCES<config-icon.jpg>.Str;
note "'$icon'";
#        my Int() $icon-size = $!dispatch-config<theme><iconsize> // 64;
        my Gnome::Gtk4::Picture $p .= new-picture;
        $p.set-filename($icon);
#`{{
        my Pixbuf $pixbuf .= new(
          :file($icon), :width($icon-size),
          :height($icon-size), :preserve_aspect_ratio
        );

        my Gnome::Glib::Error $e = $pixbuf.last-error;
        if $e.is-valid {
          note "Image load error: ", $e.message;
        }

        else {
          .set-image(Image.new(:$pixbuf));
        }
}}

        .register-signal(
          self, 'execute-actions', 'clicked',
          :action-config($!dispatch-config<action-groups>{$kg}{$ks})
        );
      }

      $set-grid.attach( $sbutton, $set-count++, 0, 1, 1);
    }

    with my Frame $frame .= new-frame("  $kg  ") {
      .set-child($set-grid);
      .set-label-align( 0.05, 0.5);
    }

    $!groups-grid.attach( $frame, 0, $group-count++, 1, 1);
  }

#  $!groups-grid.show-all;
}
}}

#`{{
#-------------------------------------------------------------------------------
method !init-app-window ( Gnome::Gtk4::ScrolledWindow() $no-swin ) {
#`{{
  my Str $desktop-theme =
    $!dispatch-config<theme><desktop-theme> // 'Adwaita:dark';
  my Str ( $name, $variant) = $desktop-theme.split(':');
  my StyleContext() $context .= new;
  my CssProvider() $css-provider .= new( :$name, :$variant);
  $context.add-provider-for-screen(
    Screen.new, $css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $css-provider.clear-object;
}}
#`{{
  # Copy style sheet to data directory and load into program
  my Str $css-file = DATA_DIR ~ 'dispatcher.css';
  %?RESOURCES<dispatcher.css>.copy($css-file);
  $!css-provider .= new-cssprovider;
  $!css-provider.load-from-path($css-file);
}}
#`{{
  # set the class name of the grid managing groups
  $context = $!groups-grid.get-style-context;
  $context.add-class('groups-grid');
}}
  with $!app-window .= new-applicationwindow($!application) {
    .set-child($no-swin);
#`{{
    $context = .get-style-context;
    $context.add-class('dispatcher-window');
    $context.clear-object;
  my Str $png-file;
  for <steel-floor.jpg brushed-light.jpg> -> $i {
    $png-file = [~] DATA_DIR, 'images/', $i;
    %?RESOURCES{$i}.copy($png-file) unless $png-file.IO.e;
  }

}}
#`{{
    my Str $wallpaper =
      $!dispatch-config<theme><wallpaper> // %?RESOURCES<steel-floor.jpg>.Str;
    my Str $menu-wallpaper =
      $!dispatch-config<theme><menu-wallpaper> // %?RESOURCES<brushed-light.jpg>.Str;
    my Str $groups-grid-color =
      $!dispatch-config<theme><groups-grid-color> // '255, 255, 255, 0';
    my Str $frame-tfg = $!dispatch-config<theme><frame-text-fg> // 'white';
    my Str $frame-tbg =
      $!dispatch-config<theme><frame-text-bg> // 'transparent';
    my Str $css = [~]
        '.dispatcher-window {', "\n",
        '  background: url("', $wallpaper, '") center / cover repeat;', "\n",
        "}\n\n",

        '.groups-grid {', "\n",
        '  background-color: rgba( ', $groups-grid-color, ");\n",
        "} \n\n",

        'frame > label {', "\n",
        "  color: $frame-tfg;\n",
        "  background-color: $frame-tbg;",
        "  font-weight: bold;\n",
        "  border-radius: 8px;\n",
        "}\n\n",

        'menubar {', "\n",
        '  background: url("', $menu-wallpaper, '") center / cover repeat;', "\n",
        "}\n";
#note "\ncss\n$css";
}}
#`{{
    $css-provider .= new;
    $css-provider.load-from-data($css);
    #$context .= new;
    $context.add-provider-for-screen(
      Screen.new, $css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
    );
    $css-provider.clear-object;
}}

    .set-size-request( $!config.get-width, $!config.get-height);
    .set-title($!config.get-title);
#`{{
    my Str $icon = $!dispatch-config<theme><icon-file> //
                   %?RESOURCES<config-icon.jpg>.Str;
    my Pixbuf $win-icon .= new(
      :file($icon), :width(32), :height(32), :preserve_aspect_ratio
    );
    my Gnome::Glib::Error $e = $win-icon.last-error;
    if $e.is-valid {
      die "Error icon file: $e.message()";
    }

    else {
      .set-icon($win-icon);
    }
}}

#    .register-signal( self, 'exit-program', 'destroy');
    .show;
  }
}
}}

#-------------------------------------------------------------------------------
# Test Dispatch > Testing On/Off
method test-dispatch (
#  Gnome::Glib::Variant() $value,
  Gnome::Gio::SimpleAction() :_native-object($test-mode-action),
) {
#note 'valid action: ', $test-mode-action.is-valid;
#note 'valid no: ', $no.gist;

#note "Select 'test' from 'configure' menu";
#note $test-mode-action.get-name;
#  my Str $test-state = $value.print();
#note "Set to $test-state";
#  $!dispatch-testing = $test-state eq 'test-on' ?? True !! False;

#  $test-mode-action.set-state(
#    Gnome::Glib::Variant.new(:parse($value.print))
#  );
}

#`{{
#-------------------------------------------------------------------------------
# Help > Index
method show-index ( N-Object $parameter ) {
#  note "Select 'Index' from 'Help' menu";
}
}}

#-------------------------------------------------------------------------------
method execute-actions ( Hash :$action-config --> Bool ) {
  my Array $cmd-list = self.get-all-actions($action-config);
  self.dispatch($cmd-list);
}

#-------------------------------------------------------------------------------
#-- [menu entries] -------------------------------------------------------------
# Dispatch > New
method new-group ( N-Object $n-parameter ) {
#  my Gnome::Glib::Variant $v .= new(:native-object($n-parameter));
#  note $v.print() if $v.is-valid;
  note "Select 'New' from 'File' menu";
}

#-------------------------------------------------------------------------------
# Dispatch > Quit
method app-quit ( N-Object $n-parameter ) {
  note "Select 'Quit' from 'File' menu";
#  my Gnome::Glib::Variant $v .= new(:native-object($n-parameter));
#  note $v.print() if $v.is-valid;

#  self.quit;
}

#-------------------------------------------------------------------------------
# Help > About
method show-about ( N-Object $parameter ) {
#  note "Select 'About' from 'Help' menu";
}
