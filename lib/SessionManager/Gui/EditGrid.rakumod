use v6.d;

use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

use SessionManager::Gui::EditVariableGrid;
use SessionManager::Gui::EditActionGrid;
use SessionManager::Gui::EditSessionGrid;

use SessionManager::Config;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditGrid;
also is Gnome::Gtk4::Box;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditGrid ) {
  self.new-box( GTK_ORIENTATION_HORIZONTAL, 0, |c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  my SessionManager::Config $config .= instance;
  $config.theme.add-css-class( self, 'main-edit-grid');

  with self {
    my SessionManager::Gui::EditVariableGrid $variables .= new;
    .append($variables);

    my SessionManager::Gui::EditActionGrid $actions .= new;
    .append($actions);

#`{{
    my SessionManager::Gui::EditSessionGrid $sessions .= new;
    .append($sessions);
}}
  }
}

#-------------------------------------------------------------------------------
