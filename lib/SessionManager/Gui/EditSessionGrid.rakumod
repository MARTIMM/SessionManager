use v6.d;

use Gnome::Gtk4::Grid:api<2>;

use GnomeTools::Gtk::ListView;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditSessionGrid;
also is Gnome::Gtk4::Grid;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditSessionGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
