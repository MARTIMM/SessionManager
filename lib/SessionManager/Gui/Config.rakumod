v6.d;

#use YAMLish;

use SessionManager::Config;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListBox;

use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
#use Gnome::Gtk4::ListBox:api<2>;
use Gnome::Gtk4::ListBoxRow:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Widget:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;
use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);


#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Config;

has SessionManager::Config $!config;

constant Dialog = GnomeTools::Gtk::Dialog;
constant DropDown = GnomeTools::Gtk::DropDown;
constant ListBox = GnomeTools::Gtk::ListBox;
constant ListBoxRow = Gnome::Gtk4::ListBoxRow;

#constant Actions = SessionManager::Gui::Actions;
constant Actions = SessionManager::Actions;

constant Entry = Gnome::Gtk4::Entry;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Label = Gnome::Gtk4::Label;
constant Widget = Gnome::Gtk4::Widget;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!config .= instance;
}

