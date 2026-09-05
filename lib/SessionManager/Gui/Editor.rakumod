
use v6.d;

use Getopt::Long;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use Gnome::Gio::T-ioenums:api<2>;

use Gnome::Gtk4::T-enums:api<2>;

use GnomeTools::Gio::Menu;

use GnomeTools::Gtk::Application;

#use SessionManager::Actions;
#use SessionManager::Sessions;
#use SessionManager::Variables;
use SessionManager::Config;
#use SessionManager::Gui::Toolbar;
#use SessionManager::Gui::Actions;
#use SessionManager::Gui::Variables;
#use SessionManager::Gui::Sessions;
#use SessionManager::Gui::Config;
use SessionManager::Gui::EditGrid;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Editor:auth<github:MARTIMM>;

constant APP_ID is export = 'io.github.martimm.session-manager';

constant LocalOptions = [<help|h>];

has GnomeTools::Gtk::Application $!application;
has Int $.exit-code = 0;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  with $!application .= new(
    :app-id(APP_ID),
    :app-flags(
      G_APPLICATION_HANDLES_COMMAND_LINE +|
      G_APPLICATION_NON_UNIQUE
    )
  ) {
    .set-activate( self, 'app-activate');
#    .set-startup( self, 'startup');
    .set-shutdown( self, 'shutdown');

    .process-local-options( self, 'local-options');
    .process-remote-options( self, 'remote-options');

    $!exit-code = .run;
  }
}

#-------------------------------------------------------------------------------
method local-options ( --> Int ) {

  # get-options() dies when unknown options are passed
  CATCH { default { .message.note; $!exit-code = 1; return $!exit-code; } }

  # By default, continue to proces remote options and/or activation of
  # primary instance
  $!exit-code = -1;

  # Keeps all options from @*ARGS because of :!overwrite.
  # Local options which do not need a config file or primary instance
  my $o = get-options( |LocalOptions, :!overwrite);
  if $o<h>:exists or $o<help>:exists {
    # When set to 1, the main program will always show the help message
    $!exit-code = 1;
  }

  $!exit-code
}

#-------------------------------------------------------------------------------
method remote-options ( Array $args, Bool :$is-remote --> Int ) {
  $!exit-code = 0;
#note "$?LINE $args.gist()";

  if $args.elems < 2 {
    $!exit-code = 1;
    note "\nYou must specify a sesion directory";
  }

  else {
    $*config-directory = $args[1];
    if $*config-directory.IO.absolute.Str eq
       "$*HOME/Languages/Raku/Projects/SessionManager"
    {
      $!exit-code = 1;
      note "\nConfiguration path '$*config-directory' cannot be in my projects dir";
    }

    elsif $*config-directory.IO ~~ :d {
      # Now initialize configuration.
      my SessionManager::Config $config .= instance(:reinit);
      $!application.set-window-content(
        self.window-content, self.menu, :title($config.get-window-title)
      );

      # finish up
#      $!application.activate unless $is-remote;
    }

    else {
      $!exit-code = 1;
      note "\nConfiguration path '$*config-directory' is not a directory (or wrong one)";
    }
  }

  $!exit-code
}

#-------------------------------------------------------------------------------
method shutdown ( ) {
  self.save-config unless $!exit-code;
}

#-------------------------------------------------------------------------------
# Called after registration of the application
#method startup ( ) {
#}

#-------------------------------------------------------------------------------
# Activation of the application takes place when processing remote options
# reach the default entry, or when setup options are processed.
# And when this process is also the primary instance, it's only called once
# because we don't need to create two gui's. This is completely automatically
# done.
method app-activate ( ) {
#  my SessionManager::Config $config .= instance;
#  $!application.set-window-content(
#    self.window-content, self.menu, :title($config.get-window-title)
#  );
}

#-------------------------------------------------------------------------------
method window-content ( --> SessionManager::Gui::EditGrid ) {

  my SessionManager::Gui::EditGrid $session-manager-box .= new;
  $session-manager-box
}

#-------------------------------------------------------------------------------
method menu ( --> GnomeTools::Gio::Menu ) {

#  my SessionManager::Gui::Actions $action-edit .= instance;
#  my SessionManager::Gui::Variables $variable-edit .= instance;
#  my SessionManager::Gui::Sessions $session-edit .= instance;
#  my SessionManager::Gui::Config $config-edit .= instance;

  my GnomeTools::Gio::Menu $bar .= new;
  my GnomeTools::Gio::Menu $parent-menu = $bar;
  with my GnomeTools::Gio::Menu $m1 .= new( :$parent-menu, :name<File>) {
    $parent-menu = $m1;
    with my GnomeTools::Gio::Menu $sc2 .= new( :$parent-menu, :section(Str)) {
      .item( 'Quit', self, 'file-quit');
    }
  }

  $bar
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  $!application.quit;
}

#-------------------------------------------------------------------------------
method save-config ( ) {
  # save changed config
  my SessionManager::Variables $variables .= new;
  my SessionManager::Actions $actions .= new;
  my SessionManager::Sessions $sessions .= new;
  $actions.save;
  $variables.save;
  $sessions.save;
}


