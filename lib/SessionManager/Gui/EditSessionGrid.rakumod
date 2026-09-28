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
use SessionManager::Gui::Actions;

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

has SessionManager::Sessions $!sessions;

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

  $!sessions .= new;
  $!actions .= new;
  $!variables .= new;

  self.init-fields;

  my &addc = $SessionManager::Gui::EditTools::add-content2.assuming(
    self, *
  );

  my Int $row = 0;
  addc( $row++, make-title('Sessions'));
  addc( $row++, make-vertical-space);
  addc( $row++, self!dialog-grid);
  addc( $row++, $!statusbar .= new);
  addc( $row++, self!button-row);
  addc( $row++, make-vertical-space);
  addc( $row++, $!actions-view);
  addc( $row++, make-vertical-space);

  my Entry $search = make-entry;
#    $search.set-size-request( 250, -1);
  with my Button $search-button .= new-button {
    .set-label('Select from list');
    .register-signal( self, 'select-from-list', 'clicked', :$search);
  }
  with my Button $reset-button .= new-button {
    .set-label('Reset search');
    .register-signal( self, 'reset-list', 'clicked', :$search);
  }

  my Box $bt-box .= new-box( GTK_ORIENTATION_HORIZONTAL, 10);
  $bt-box.append($search);
  $bt-box.append($search-button);
  $bt-box.append($reset-button);
  addc( $row++, $bt-box);
  addc( $row++, make-vertical-space);
}

#-------------------------------------------------------------------------------
method !dialog-grid ( --> Grid ) {
  $!sessions-dd.set-selection-changed( self, 'trap-select-session');

  # Fill the session drop down with the session ids and select the first one
  my @session-ids = $!sessions.get-session-ids.sort;
  if @session-ids.elems {
    $!sessions-dd.append(@session-ids);
  }

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
method !button-row ( --> Box ) {

  my Button $button;
  with my Box $button-row .= new-box( GTK_ORIENTATION_HORIZONTAL, 4) {
#    my Label $hstrut = make-label;
#    $hstrut.set-text('');
#    .append($hstrut);

    with $button .= new-button {
      .set-label('Add');
      .register-signal( self, 'action-add', 'clicked');
    }
    .append($button);

    with $button .= new-button {
      .set-label('Rename');
      .register-signal( self, 'action-rename', 'clicked');
    }
    .append($button);

    with $button .= new-button {
      .set-label('Modify');
      .register-signal( self, 'action-modify', 'clicked');
    }
    .append($button);

    with $button .= new-button {
      .set-label('Delete');
      .register-signal( self, 'action-delete', 'clicked');
    }
    .append($button);
  }

  $button-row
}

#-------------------------------------------------------------------------------
method select-from-list ( Entry :$search ) {
  my Str $search-text = $search.get-text;
  my @actions = $!actions.get-action-ids.sort: {$^a.lc leg $^b.lc};
  $!actions-view.remove(0..^@actions.elems);
  for @actions -> $item {
    $!actions-view.append($item) if $item ~~ m/ $search-text /;
  }
}

#-------------------------------------------------------------------------------
method reset-list ( Entry :$search ) {
  $!actions-view.remove(^$!actions-view.get-n-items);
  $!actions-view.append($!actions.get-action-ids.sort: {$^a.lc leg $^b.lc});
  $search.set-text('');
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

  with $!actions-view .= new(:!multi-select) {
#NOTE with set-size-request() many warnings come;
# (sessioneditor:20240): Gtk-WARNING **: 14:24:34.559: Trying to measure
# GtkApplicationWindow 0x3faba110 for height of 1300, but it needs at least 1362
#    .set-size-request( -1, 500);
# The listview will stretch automatically because of the height of the
# variables edit at the first column of the box

    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

#    .set-selection-changed( self, 'set-input-fields');

    .append($!actions.get-action-ids.sort: {$^a.lc leg $^b.lc});
#    .append($!actions.get-action-idss[^2]);

    # Select the first one
    .set-selection(0);
  }
}

#-------------------------------------------------------------------------------
# Selecting from session dropdown must set the id and title text entry
method trap-select-session ( ) {
  my Str $sid = $!sessions-dd.get-text;
  $!session-id.set-text($sid);

  my Str $t = $!sessions.get-session-title($sid);
  $!session-title.set-text($t);
  $!session-title-subst.set-text($!variables.substitute-vars($t));

  $t = $!sessions.get-session-icon($sid);
  $!session-icon.set-text($t);
  $!session-icon-subst.set-text($!variables.substitute-vars($t));

#  $t = $!sessions.get-session-overlay($sid);
#  $!session-overlay.set-text($t);
#  $!session-overlay-subst.set-text($!variables.substitute-vars($t));
}

#-------------------------------------------------------------------------------
method setup-item ( ) {
  my Label $action-id = make-label;
  my Label $action-value = make-label;
  my Image $used = make-image;

  with my Grid $grid .= new-grid {
    .attach( $used, 0, 0, 2, 2);
    .attach( $action-id, 2, 0, 1, 1);
    .attach( $action-value, 2, 1, 1, 1);
  }

  $grid;
}

#-------------------------------------------------------------------------------
method bind-item ( Gnome::Gtk4::Grid() $grid, Str $name ) {
  my Hash $action-object = $!actions.get-raw-action($name);
  set-text-at( 2, 0, $name, $grid);
  set-text-at( 2, 1, $action-object<t>//'', $grid);

  my Str $sessionid = $!sessions-dd.get-text;
  my Bool $name-inuse = $!sessions.is-action-in-use-in-session(
    $sessionid, $name
  );

  # Select the items found in this group
#  my @group-actions = $!sessions.get-actions($sessionid);
#  @group-actions.push: $!actions-view.find($ga);
#  $!actions-view.set-selection(@group-actions);

  self.set-image-at( 0, 0, 'green', $name, $name-inuse, $grid);
}

#-------------------------------------------------------------------------------
method check-action-inuse ( Str:D $name --> Bool ) {
  # Check if action is used in the sessions store
  $!sessions.is-action-in-use($name);
}

#-------------------------------------------------------------------------------
#method unbind-item

#-------------------------------------------------------------------------------
method teardown-item ( Gnome::Gtk4::Grid() $grid ) {
  $grid.clear-object;
}
