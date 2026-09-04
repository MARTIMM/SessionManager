use v6.d;

use Gnome::Gtk4::Grid:api<2>;
use SessionManager::Gui::EditVariableGrid;
use SessionManager::Gui::EditActionGrid;
use SessionManager::Gui::EditSessionGrid;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditGrid;
also is Gnome::Gtk4::Grid;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  my SessionManager::Gui::EditVariableGrid $variables .= new;
  self.attach( $variables, 0, 0, 1, 1);

  my SessionManager::Gui::EditActionGrid $actions .= new;
  self.attach( $actions, 1, 0, 1, 1);

  my SessionManager::Gui::EditSessionGrid $sessions .= new;
  self.attach( $sessions, 2, 0, 1, 1);
}

#-------------------------------------------------------------------------------
