v6.d;

use YAMLish;

use SessionManager::Gui::Actions;

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

constant ConfigPath = '/Config/sessions.yaml';
my SessionManager::Gui::Sessions $instance;

constant Dialog = GnomeTools::Gtk::Dialog;
constant DropDown = GnomeTools::Gtk::DropDown;
constant ListBox = GnomeTools::Gtk::ListBox;
constant ListBoxRow = Gnome::Gtk4::ListBoxRow;

constant Actions = SessionManager::Gui::Actions;

constant Entry = Gnome::Gtk4::Entry;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Label = Gnome::Gtk4::Label;
constant Widget = Gnome::Gtk4::Widget;

has Hash $!sessions;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!sessions = %();
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Sessions ) {
  $instance //= self.bless;

  $instance
}

#-------------------------------------------------------------------------------
method load-session ( Str $name, Str $path ) {
  $!sessions{$name} = load-yaml($path.IO.slurp);
}

#-------------------------------------------------------------------------------
method add-session ( Str $name, Hash $session ) {
  $!sessions{$name} = $session;
}

#-------------------------------------------------------------------------------
method get-session-names ( --> Seq ) {
  $!sessions.keys
}

#-------------------------------------------------------------------------------
method get-session ( Str $name --> Hash ) {
  $!sessions{$name}
}

#-------------------------------------------------------------------------------
method get-sessions ( --> Hash ) {
  $!sessions
}

#-------------------------------------------------------------------------------
method save ( ) {
  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($!sessions));
}

#-------------------------------------------------------------------------------
method load ( ) {
  if ($*config-directory ~ ConfigPath).IO.r {
    $!sessions = load-yaml(($*config-directory ~ ConfigPath).IO.slurp);
  }
}

#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method sessions-add-rename ( N-Object $parameter ) {
  my Actions $actions .= instance;

  with my Dialog $dialog .= new(
    :dialog-header('Modify Session'), :add-statusbar
  ) {
    my Entry $sessionid-e .= new-entry;
    my Entry $sessiontitle-e .= new-entry;

    # Setup the dropdown to show the session ids
    my DropDown $sessions-dd .= new;

    # Fill the session drop down with the session ids and select the first one
    my Array $session-ids = [$!sessions.keys.sort];
    if $session-ids.elems {
      $sessions-dd.set-selection($session-ids);
      $sessions-dd.select($session-ids[0]);

      # Set entry with text of first session id and its title
      $sessionid-e.set-text($session-ids[0]);
      $sessiontitle-e.set-text($!sessions{$session-ids[0]}<title>);
    }

    # Trap changes in the sessions list
    $sessions-dd.trap-dropdown-changes(
      self, 'trap-select-session', :$sessions-dd,
      :$sessionid-e, :$sessiontitle-e
    );

    # Add entries and dropdown widgets in the dialog
    .add-content( 'Session list', $sessions-dd);
    .add-content( 'Session id', $sessionid-e);
    .add-content( 'Session title', $sessiontitle-e);

    # Add buttons to the dialog
    .add-button(
      self, 'do-add-session', 'Add', :$dialog,
      :$sessions-dd, :$sessionid-e, :$sessiontitle-e
    );

    .add-button(
      self, 'do-rename-session', 'Rename', :$dialog,
      :$sessions-dd, :$sessionid-e, :$sessiontitle-e
    );

    .add-button(
      self, 'do-change-session', 'Change', :$dialog,
      :$sessions-dd, :$sessionid-e, :$sessiontitle-e
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
# Selecting from session dropdown must set the id and title text entry
method trap-select-session (
  N-Object $, DropDown :$sessions-dd,
  Entry :$sessionid-e, Entry :$sessiontitle-e
) {
  my Str $sid = $sessions-dd.get-text;
  $sessionid-e.set-text($sid);
  $sessiontitle-e.set-text($!sessions{$sid}<title>);
}

#-------------------------------------------------------------------------------
method do-add-session (
  Dialog :$dialog, DropDown :$sessions-dd,
  Entry :$sessionid-e, Entry :$sessiontitle-e
) {
  my Str $sid = $sessionid-e.get-text;
  my Str $current-sid = $sessions-dd.get-text;

  if $sid eq $current-sid {
    $dialog.set-status("$sid already defined");
  }

  else {
    # Set the title of the session
    $!sessions{$sid}<title> = $sessiontitle-e.get-text;

    # Always add a group with an actions key
    $!sessions{$sid}<group1> = %(:actions([]));

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
  Entry :$sessionid-e, Entry :$sessiontitle-e
) {
  my Str $sid = $sessionid-e.get-text;
  my Str $current-sid = $sessions-dd.get-text;

  # Change the title of the session
  $!sessions{$sid}<title> = $sessiontitle-e.get-text;

  # Success
  $dialog.set-status("$sid successfully changed");
}

#-------------------------------------------------------------------------------
method do-rename-session (
  Dialog :$dialog, DropDown :$sessions-dd, Entry :$sessionid-e
) {
  my Str $sid = $sessionid-e.get-text;
  my Str $current-sid = $sessions-dd.get-text;
  if $sid eq $current-sid {
    $dialog.set-status("$sid already defined");
  }

  else {
    $!sessions{$sid} = $!sessions{$current-sid}:delete;
    $dialog.set-status("$current-sid successfully renamed to $sid");
  }
}

#-------------------------------------------------------------------------------
method sessions-add-rename-group ( N-Object $parameter, ) {
  my Actions $actions .= instance;

  with my Dialog $dialog .= new(
    :dialog-header('Modify Session'), :add-statusbar
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
    $sessions-dd.set-selection($!sessions.keys.sort);

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

  # Add a group key. names are labeled: group1, group2, etc. with a maximum of 5
  for 1..6 -> $group-count {
    if $group-count >= 6 {
      $dialog.set-status("maximum number of groups reached");
      last;
    }

    my Str $new-group = "group$group-count";
    next if $!sessions{$sessionid}{$new-group}:exists;

    # Add a new group, set its title and add an actions key
    $!sessions{$sessionid}{$new-group}<title> = $grouptitle.get-text;
    $!sessions{$sessionid}{$new-group}<actions> = [];

    # Insert the group name in the dropdown and select the group
    $groups-dd.add-selection($new-group);
    $groups-dd.select($new-group);

    $dialog.set-status("$new-group is succesfully added");
    last;
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

  $!sessions{$sessionid}{$group}<title> = $grouptitle.get-text;
  $dialog.set-status("$group is succesfully changed");
}

#-------------------------------------------------------------------------------
method sessions-add-remove-actions ( N-Object $parameter ) {
  my Actions $actions .= instance;

  with my Dialog $dialog .= new(
    :dialog-header('Modify Session'), :add-statusbar
  ) {
    my DropDown $groups-dd .= new;
    my DropDown $sessions-dd .= new;
    my Label $grouptitle .= new-label;
    my Label $sessiontitle .= new-label;

#    my ListBox $sessions-actions-list;
    my ListBox $all-actions-list;

    # Fill the sessions list.
    my @session-ids = $!sessions.keys.sort;
    $sessions-dd.set-selection(@session-ids);
    $sessions-dd.select(@session-ids[0]);

    # Create the listbox to list all actions.
    $all-actions-list .= new(:multi);
    my ScrolledWindow $sw2 = $all-actions-list.set-list([|$actions.get-ids]);

    # Fill the groups list.
    $groups-dd.set-selection(
      $!sessions{@session-ids[0]}.keys.grep(/^group/).sort
    );

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
    .add-content( 'Group title', :2columns);
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
  $!sessions{$c-session}{$c-group}<actions> = $listbox.get-selection;

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

  $groups-dd.set-selection($!sessions{$sessionid}.keys.grep(/^group/).sort);

  my Str $group-name = $groups-dd.get-text // '';
  $grouptitle.set-text($!sessions{$sessionid}{$group-name}<title> // '');

  $sessiontitle.set-text($!sessions{$sessionid}<title>);

}

#------------------------------------------------------------------------------
method set-grouptitle (
  N-Object $, DropDown :$sessions-dd, DropDown :$groups-dd,
  Widget :$grouptitle, ListBox :$all-actions-list
) {
note "$?LINE";
  my Str $session-id = $sessions-dd.get-text;
  my Str $group-name = $groups-dd.get-text;
  $grouptitle.set-text($!sessions{$session-id}{$group-name}<title> // '');

  my Array $s-actions = $!sessions{$session-id}{$group-name}<actions> // [];
  $all-actions-list.set-selection($s-actions);
}

#-------------------------------------------------------------------------------
method sessions-delete (
  N-Object $parameter
) {
}
