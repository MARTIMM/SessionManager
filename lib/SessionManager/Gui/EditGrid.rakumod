use v6.d;

use Gnome::Gtk4::Grid:api<2>;

use SessionManager::Gui::EditVariableGrid;
use SessionManager::Gui::EditActionGrid;
use SessionManager::Gui::EditSessionGrid;

use SessionManager::Config;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditGrid;
also is Gnome::Gtk4::Grid;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  my SessionManager::Config $config .= instance;
  $config.theme.add-css-class( self, 'main-edit-grid');

  with self {
    my SessionManager::Gui::EditVariableGrid $variables .= new;
    .attach( $variables, 0, 0, 1, 1);

    my SessionManager::Gui::EditActionGrid $actions .= new;
    .attach( $actions, 1, 0, 1, 1);

    my SessionManager::Gui::EditSessionGrid $sessions .= new;
    .attach( $sessions, 2, 0, 1, 1);

    .set-column-spacing(20);
    .set-row-spacing(20);
  }
}

#-------------------------------------------------------------------------------
