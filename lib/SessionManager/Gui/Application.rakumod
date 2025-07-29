
use v6.d;

use NativeCall;

use Getopt::Long;

#use Gnome::Gtk4::CssProvider:api<2>;
#use Gnome::Gtk4::StyleContext:api<2>;
#use Gnome::Gtk4::T-styleprovider:api<2>;

use Gnome::Gtk4::Application:api<2>;
use Gnome::Gtk4::ApplicationWindow:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
#use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Grid:api<2>;

use Gnome::Gio::ApplicationCommandLine:api<2>;
use Gnome::Gio::T-ioenums:api<2>;

use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

#use SessionManager::Actions;
use SessionManager::Config;
use SessionManager::Gui::Toolbar;
use SessionManager::Gui::MenuBar;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Application:auth<github:MARTIMM>;

constant Grid = Gnome::Gtk4::Grid;

has Gnome::Gtk4::Application $.application;
has Gnome::Gtk4::ApplicationWindow $.app-window;
#has SessionManager::Gui::Toolbar $!toolbar;
#has SessionManager::Config $!config;

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
#  $!application.register-signal( self, 'shutdown', 'shutdown');

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
#note "$?LINE $args.gist()";

  if $o<v>:exists or $o<verbose>:exists {
    $*verbose = True;
  }

  # Modify image map. Default is at <config>/Images.
  $*images = $o<images> if ? $o<images>;

  # Modify parts map. Default is at <config>/Parts.
  #$*parts = $o<parts> if ? $o<parts>;

  my Str $config-directory;
  if ? $o<config> {
    $config-directory = $o.<config> // Str;
  }

  my SessionManager::Config $config .= instance(:$config-directory);

  $config.set-legacy(?$o<legacy>);

  # finish up
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

  with $!app-window .= new-applicationwindow($!application) {

    # Use of grid makes it easier to remove boxes from the grid later on
    my Grid $session-manager-box .= new-grid;
    my SessionManager::Gui::Toolbar $toolbar .= new-box(
      GTK_ORIENTATION_VERTICAL, 1, :$session-manager-box, :$!app-window
    );
    $session-manager-box.attach( $toolbar, 0, 0, 1, 1);

    my SessionManager::Config $config .= instance;

#    my SessionManager::Actions $actions .= new( :$!config, :$!app-window);
    my SessionManager::Gui::MenuBar $menu-bar .= new(:main(self));
    $!application.set-menubar($menu-bar.bar);
    .set-show-menubar(True);

#    .set-vexpand-set(True);
#    .set-vexpand(True);
    .set-valign(GTK_ALIGN_FILL);

    .set-title($config.get-window-title);
    .set-child($session-manager-box);

    .set-default-size($config.get-window-size);

    .present;
  }
}

#-------------------------------------------------------------------------------
# Handled after pressing the close button added by the desktop manager
method exit-program ( ) {
  self.quit;
}




=finish
#-------------------------------------------------------------------------------
method shutdown ( ) {
  # save changed config?
}
