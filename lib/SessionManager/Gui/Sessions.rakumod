v6.d;

#use YAMLish;

use SessionManager::Sessions;
#use SessionManager::Gui::Actions;
use SessionManager::Actions;
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
unit class SessionManager::Gui::Sessions;

my SessionManager::Gui::Sessions $instance;
has SessionManager::Sessions $!sessions;

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
  $!sessions .= new;
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Sessions ) {
  $instance //= self.bless;

  $instance
}

#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method add-rename ( N-Object $parameter ) {
#  my Actions $actions .= instance;

  with my Dialog $dialog .= new(
    :dialog-header('Add or Rename Session'), :!modal, :add-statusbar, :600width
  ) {
    my Entry $sessionid-e .= new-entry;
    my Entry $sessiontitle-e .= new-entry;
    my Entry $sessionicon-e .= new-entry;
    my Entry $sessionoverlay-e .= new-entry;

    # Setup the dropdown to show the session ids
    my DropDown $sessions-dd .= new;

    # Fill the session drop down with the session ids and select the first one
    my Array $session-ids = [$!sessions.get-session-ids.sort];

    # Trap changes in the sessions list
    $sessions-dd.trap-dropdown-changes(
      self, 'trap-select-session', :$sessions-dd,
      :$sessionid-e, :$sessiontitle-e,
      :$sessionicon-e, :$sessionoverlay-e
    );

    if $session-ids.elems {
      $sessions-dd.set-selection($session-ids);
      $sessions-dd.select($session-ids[0]);
    }

    # Add entries and dropdown widgets in the dialog
    .add-content( 'Session list', $sessions-dd, :4columns);
    .add-content( 'Id and title', [ 1, $sessionid-e, 3, $sessiontitle-e]);
    .add-content( 'icon', $sessionicon-e, :4columns);
    .add-content( 'overlay', $sessionoverlay-e, :4columns);

    # Add buttons to the dialog
    .add-button(
      self, 'do-add-session', 'Add', :$dialog,
      :$sessions-dd, :$sessionid-e, :$sessiontitle-e,
      :$sessionicon-e, :$sessionoverlay-e
    );

    .add-button(
      self, 'do-rename-session', 'Rename', :$dialog,
      :$sessions-dd, :$sessionid-e
    );

    .add-button(
      self, 'do-change-session', 'Change', :$dialog,
      :$sessions-dd, :$sessionid-e, :$sessiontitle-e,
      :$sessionicon-e, :$sessionoverlay-e
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
# Selecting from session dropdown must set the id and title text entry
method trap-select-session (
  N-Object $, DropDown :$sessions-dd,
  Entry :$sessionid-e, Entry :$sessiontitle-e,
  Entry :$sessionicon-e, Entry :$sessionoverlay-e
) {
  my Str $sid = $sessions-dd.get-text;
  $sessionid-e.set-text($sid);
  $sessiontitle-e.set-text($!sessions.get-session-title($sid));
  $sessionicon-e.set-text($!sessions.get-session-icon($sid));
  $sessionoverlay-e.set-text($!sessions.get-session-overlay($sid));
}

#-------------------------------------------------------------------------------
method do-add-session (
  Dialog :$dialog, DropDown :$sessions-dd,
  Entry :$sessionid-e, Entry :$sessiontitle-e,
  Entry :$sessionicon-e, Entry :$sessionoverlay-e
) {
note $?LINE;
  my Str $sid = $sessionid-e.get-text;
  my Str $current-sid = $sessions-dd.get-text;

note "$?LINE $sid eq $current-sid";

  if $sid eq $current-sid {
    $dialog.set-status("$sid already defined");
  }

  else {
    # Set the title, icon and overlay of the session
    $!sessions.set-session-title( $sid, $sessiontitle-e.get-text);
    $!sessions.set-session-icon( $sid, $sessionicon-e.get-text);
    $!sessions.set-session-overlay( $sid, $sessionoverlay-e.get-text);

    # Always add a group with an actions key
    $!sessions.set-group-actions( $sid, 'group1', []);

    # Add to the dropdown list and select
    $sessions-dd.add-selection($sid);
    $sessions-dd.select($sid);

    # Success
    $dialog.set-status("$sid successfully added");
  }
}

#-------------------------------------------------------------------------------
method do-change-session (
  Dialog :$dialog, DropDown :$sessions-dd,
  Entry :$sessionid-e, Entry :$sessiontitle-e,
  Entry :$sessionicon-e, Entry :$sessionoverlay-e
) {
  my SessionManager::Config $config .= instance;
  my Str $sid = $sessionid-e.get-text;
  my Str $current-sid = $sessions-dd.get-text;

  # Change the title, icon and overlay of the session
  $!sessions.set-session-title( $sid, $sessiontitle-e.get-text);
  $!sessions.set-session-icon(
    $sid, $config.set-picture($sessionicon-e.get-text)
  );
  $!sessions.set-session-overlay(
    $sid, $config.set-picture($sessionoverlay-e.get-text)
  );

  # Success
  $dialog.set-status("$sid successfully changed");
}

#-------------------------------------------------------------------------------
method do-rename-session (
  Dialog :$dialog, DropDown :$sessions-dd, Entry :$sessionid-e
) {
  my Str $new-sid = $sessionid-e.get-text;
  my Str $current-sid = $sessions-dd.get-text;
  if $new-sid eq $current-sid {
    $dialog.set-status("$new-sid already defined");
  }

  else {
    $!sessions.rename-session( $current-sid, $new-sid);
    $dialog.set-status("$current-sid successfully renamed to $new-sid");
  }
}

#-------------------------------------------------------------------------------
method add-rename-group ( N-Object $parameter, ) {
#  my Actions $actions .= instance;

  with my Dialog $dialog .= new(
    :dialog-header('Modify Session Group'), :!modal, :add-statusbar
  ) {
    my DropDown $groups-dd .= new;
    my DropDown $sessions-dd .= new;
    my Entry $grouptitle .= new-entry;
    my Label $sessiontitle .= new-label;

    # Trap changes in the sessions list
    $sessions-dd.trap-dropdown-changes(
      self, 'set-grouplist', :$sessions-dd, :$groups-dd,
      :$sessiontitle, :$grouptitle
    );

    # Trap changes in the group list
    $groups-dd.trap-dropdown-changes(
      self, 'set-grouptitle', :$sessions-dd, :$groups-dd, :$grouptitle
    );

    # Fill the sessions list. Triggers the .set-grouplist() and
    # .set-grouptitle() call back routines.
    $sessions-dd.set-selection($!sessions.get-session-ids.sort);

    # Add entries and dropdown widgets
    .add-content( 'Current session', $sessions-dd, $sessiontitle);
    .add-content( 'Current group', $groups-dd, $grouptitle);

    # Add buttons
    .add-button(
      self, 'do-add-group', 'Add Group',
      :$dialog, :$sessions-dd, :$groups-dd, :$grouptitle, 
    );

    .add-button(
      self, 'do-change-group', 'Change Group Title',
      :$dialog, :$sessions-dd, :$groups-dd, :$grouptitle, 
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-add-group (
  Dialog :$dialog, DropDown :$sessions-dd,
  DropDown :$groups-dd, Widget :$grouptitle,
) {
  my Str $sessionid = $sessions-dd.get-text;

  my $new-group = $!sessions.add-group( $sessionid, $grouptitle.get-text);
  if ?$new-group {
    # Insert the group name in the dropdown and select the group
    $groups-dd.add-selection($new-group);
    $groups-dd.select($new-group);

    $dialog.set-status("$new-group is succesfully added");
  }

  else {
    $dialog.set-status("maximum number of groups reached");
  }
}

#-------------------------------------------------------------------------------
# Changing the group is only a change for its title
method do-change-group (
  Dialog :$dialog, DropDown :$sessions-dd,
  DropDown :$groups-dd, Widget :$grouptitle,
) {
  my Str $sessionid = $sessions-dd.get-text;
  my Str $group = $groups-dd.get-text;

  $!sessions.set-group-title( $sessionid, $group, $grouptitle.get-text);
  $dialog.set-status("$group is succesfully changed");
}

#-------------------------------------------------------------------------------
method delete-group ( N-Object $parameter, ) {
  note "Delete group";
}

#-------------------------------------------------------------------------------
method add-remove-actions ( N-Object $parameter ) {
  my Actions $actions .= new;

  with my Dialog $dialog .= new(
    :dialog-header('Modify Session'), :!modal, :add-statusbar
  ) {
    my DropDown $groups-dd .= new;
    my DropDown $sessions-dd .= new;
    my Label $grouptitle .= new-label;
    my Label $sessiontitle .= new-label;

#    my ListBox $sessions-actions-list;
    my ListBox $all-actions-list;

    # Fill the sessions list.
    my @session-ids = $!sessions.get-session-ids.sort;
    $sessions-dd.set-selection(@session-ids);
    $sessions-dd.select(@session-ids[0]);

    # Create the listbox to list all actions.
    $all-actions-list .= new(:multi);
    my ScrolledWindow $sw2 = $all-actions-list.set-list(
      [|$actions.get-action-ids]
    );

    # Fill the groups list.
    $groups-dd.set-selection($!sessions.get-group-ids(@session-ids[0]).sort);

    # Trap changes in the sessions list
    $sessions-dd.trap-dropdown-changes(
      self, 'set-grouplist', :$sessions-dd, :$groups-dd,
      :$sessiontitle, :$grouptitle#, :$all-actions-list
    );

    # Trap changes in the group list
    $groups-dd.trap-dropdown-changes(
      self, 'set-grouptitle', :$sessions-dd, :$groups-dd,
      :$grouptitle, :$all-actions-list
    );

    # Call the callback routine once to fillout the titles of session and group
    # and make the sessions actions list visible in the actions listbox
    self.set-grouplist(
      N-Object, :$sessions-dd, :$groups-dd, :$sessiontitle, :$grouptitle, 
      :$all-actions-list
    );

    # Add entries and dropdown widgets
    .add-content( 'Current session', $sessions-dd, $sessiontitle);
    .add-content( 'Current group', $groups-dd, $grouptitle);
    .add-content( 'All Actions list', $sw2, :2columns);

    # Add buttons
    .add-button(
      self, 'set-actions', 'Done', :$dialog, :listbox($all-actions-list),
      :$sessions-dd, :$groups-dd
    );

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
# When leaving the dialog (on Done), set the sessions actions list from the
# selected entries of the total actions list
method set-actions (
  Dialog :$dialog, ListBox :$listbox,
  DropDown :$sessions-dd, DropDown :$groups-dd
) {
  my Str $c-session = $sessions-dd.get-text;
  my Str $c-group = $groups-dd.get-text;
  $!sessions.set-group-actions( $c-session, $c-group, $listbox.get-selection);

  # Remove dialog
  $dialog.destroy-dialog;
}

#-------------------------------------------------------------------------------
method set-grouplist (
  N-Object $, DropDown :$sessions-dd, DropDown :$groups-dd,
  Label :$sessiontitle, Widget :$grouptitle #, ListBox :$all-actions-list
) {
  my Str $sessionid = $sessions-dd.get-text;
  return unless ?$sessionid;

  $groups-dd.set-selection($!sessions.get-group-ids($sessionid).sort);

  my Str $group-name = $groups-dd.get-text // '';
  $grouptitle.set-text($!sessions.get-group-title( $sessionid, $group-name));

  $sessiontitle.set-text($!sessions.get-session-title($sessionid));
}

#------------------------------------------------------------------------------
method set-grouptitle (
  N-Object $, DropDown :$sessions-dd, DropDown :$groups-dd,
  Widget :$grouptitle, ListBox :$all-actions-list
) {
  my Str $session-id = $sessions-dd.get-text;
  my Str $group-name = $groups-dd.get-text;
  $grouptitle.set-text($!sessions.get-group-title( $session-id, $group-name));

  $all-actions-list.set-selection(
    $!sessions.get-group-actions( $session-id, $group-name)
  ) if ?$all-actions-list;
}

#-------------------------------------------------------------------------------
method delete (
  N-Object $parameter
) {
}
