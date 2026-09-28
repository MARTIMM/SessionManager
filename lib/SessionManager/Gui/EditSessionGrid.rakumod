use v6.d;

use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Widget:api<2>;

use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListView;
use GnomeTools::Gtk::Statusbar;

use SessionManager::Variables;
use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Config;

use SessionManager::Gui::EditTools;
use SessionManager::Config;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditSessionGrid;
also is Gnome::Gtk4::Grid;

constant DropDown = GnomeTools::Gtk::DropDown;
constant ListView = GnomeTools::Gtk::ListView;
constant Statusbar = GnomeTools::Gtk::Statusbar;

constant Entry = Gnome::Gtk4::Entry;
constant Label = Gnome::Gtk4::Label;
constant Grid = Gnome::Gtk4::Grid;
constant Button = Gnome::Gtk4::Button;
constant Box = Gnome::Gtk4::Box;
constant Image = Gnome::Gtk4::Image;
constant Widget = Gnome::Gtk4::Widget;

constant EDIT_WIDTH = 500;
constant EDIT_HEIGHT = 1000;
constant EDIT_WIDTH-CHARS = 80;

has Entry $!session-id;
has Entry $!session-title;
has Entry $!session-overlay;
has Entry $!session-icon;

has Label $!session-title-subst;
has Label $!session-overlay-subst;
has Label $!session-icon-subst;
#has Label $!sessiontitle;

# Setup the dropdown to show the session ids and groups
has DropDown $!sessions-dd;
has DropDown $!groups-dd;

has Entry $!group-title;
has Label $!group-title-subst;

# Fill the session drop down with the session ids and select the first one
#has @!session-ids;

has SessionManager::Actions $!actions;
has SessionManager::Variables $!variables;

has Statusbar $!statusbar;

has ListView $!actions-view;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditSessionGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  my SessionManager::Config $config .= instance;
  $config.theme.add-css-class( self, 'edit-grid');

  self.init-fields;

  my &addc = $SessionManager::Gui::EditTools::add-content2.assuming(
    self, *
  );

  my Int $row = 0;
  addc( $row++, make-title('Sessions'));
  addc( $row++, make-vertical-space);
  addc( $row++, self!dialog-grid);
  addc( $row++, $!statusbar .= new);
  addc( $row++, make-vertical-space);
}

#-------------------------------------------------------------------------------
method !dialog-grid ( --> Grid ) {

  my Grid $dialog-grid .= new-grid;
  my &addc = $SessionManager::Gui::EditTools::add-content1.assuming(
    $dialog-grid, *
  );

  # Add entries and dropdown widgets in the dialog
  my Int $row = 0;
  addc( $row++, 'Session list', $!sessions-dd);
  addc( $row++, 'Session id', $!session-id);
  addc( $row++, 'Title', $!session-title);
  addc( $row++, '', $!session-title-subst);
#  .add-content( 'Icon', $!session-overlay, $!session-overlay-subst);
  addc( $row++, 'Picture', $!session-icon);
  addc( $row++, '', $!session-icon-subst);

  # Add buttons to the dialog
#  .add-button( self, 'do-add-session', 'Add');
#    .add-button( self, 'do-rename-session', 'Rename');
#    .add-button( self, 'do-change-session', 'Change');
#  .add-button( $!dialog, 'destroy-dialog', 'Done');

  $dialog-grid
}

#-------------------------------------------------------------------------------
method init-fields ( Bool :$id-is-sensitive = True, :$id-only = False ) {

  with $!session-id .= new-entry {
    .set-sensitive($id-is-sensitive);
    .set-placeholder-text('unique session id');
  }

  with $!session-title .= new-entry {
    .set-sensitive(!$id-only);
#    .set-has-tooltip(True);
  }

  with $!session-icon .= new-entry {
    .set-sensitive(!$id-only);
#    .set-has-tooltip(True);
  }

#  with $!session-overlay .= new-entry {
#    .set-sensitive(!$id-only);
#    .set-has-tooltip(True);
#  }

  $!session-title-subst .= new-label;
  $!session-title-subst.set-halign(GTK_ALIGN_START);

  $!session-icon-subst .= new-label;
  $!session-icon-subst.set-halign(GTK_ALIGN_START);

#  $!session-overlay-subst .= new-label;
#  $!session-overlay-subst.set-halign(GTK_ALIGN_START);

#  with $!sessiontitle .= new-label {
#    .set-sensitive(!$id-only);
#  }

  # Setup the dropdown to show the session ids
  with $!sessions-dd .= new {
    .set-events;
  }

  # Setup the dropdown to show groups in a session
  with $!groups-dd .= new {
    .set-events;
  }

  with $!group-title .= new-entry {
    .set-sensitive(!$id-only);
#    .set-has-tooltip(True);
  }

  $!group-title-subst .= new-label;
  $!group-title-subst.set-halign(GTK_ALIGN_START);
}
