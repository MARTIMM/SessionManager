use v6.d;

use Gnome::Gtk4::Grid:api<2>;

use GnomeTools::Gtk::ListView;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditVariableGrid;
also is Gnome::Gtk4::Grid;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditVariableGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
