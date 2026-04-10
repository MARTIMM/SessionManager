v6.d;

#use YAMLish;

use SessionManager::Sessions;
use SessionManager::Gui::Actions;
use SessionManager::Actions;
use SessionManager::Variables;
use SessionManager::Config;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListBox;
use GnomeTools::Gtk::ListView;

use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Widget:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

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
constant ListView = GnomeTools::Gtk::ListView;

#constant Actions = SessionManager::Gui::Actions;
constant Actions = SessionManager::Actions;

constant Entry = Gnome::Gtk4::Entry;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Label = Gnome::Gtk4::Label;
constant Widget = Gnome::Gtk4::Widget;
constant Grid = Gnome::Gtk4::Grid;
constant Image = Gnome::Gtk4::Image;
constant Button = Gnome::Gtk4::Button;
constant Box = Gnome::Gtk4::Box;


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

has Dialog $!dialog;
has ListView $!actions-view;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!sessions .= new;
  $!actions .= new;
  $!variables .= new;
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Sessions ) {
  $instance //= self.bless;

  $instance
}

#--[menu entry sessions add]----------------------------------------------------
method add ( N-Object $parameter ) {
  self.init-fields;
  $!sessions-dd.set-selection-changed( self, 'trap-select-session');

  # Fill the session drop down with the session ids and select the first one
  my @session-ids = $!sessions.get-session-ids.sort;
  if @session-ids.elems {
    $!sessions-dd.append(@session-ids);
  }

  with $!dialog .= new(
    :dialog-header('Add Session'), :!modal, :add-statusbar, :600width
  ) {
    # Add entries and dropdown widgets in the dialog
    .add-content( 'Session list', $!sessions-dd);
    .add-content( 'Session id', $!session-id);
    .add-content( 'Title', $!session-title, $!session-title-subst);
    .add-content( 'Icon', $!session-overlay, $!session-overlay-subst);
    .add-content( 'Picture', $!session-icon, $!session-icon-subst);

    # Add buttons to the dialog
    .add-button( self, 'do-add-session', 'Add');
#    .add-button( self, 'do-rename-session', 'Rename');
#    .add-button( self, 'do-change-session', 'Change');
    .add-button( $!dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-add-session ( ) {
  my Str $sid = $!session-id.get-text;
  my Str $current-sid = $!sessions-dd.get-text;

  if $sid eq $current-sid {
    $!dialog.set-status("$sid already defined");
  }

  else {
    # Set the title, icon and overlay of the session
    $!sessions.set-session-title( $sid, $!session-title.get-text);
    $!sessions.set-session-icon( $sid, $!session-icon.get-text);
    $!sessions.set-session-overlay( $sid, $!session-overlay.get-text);

    # Always add a group with an actions key and an empty list of actions
    $!sessions.set-group-actions( $sid, 'group1');

    # Add to the dropdown list and select
    $!sessions-dd.append($sid);
    $!sessions-dd.select($sid);

    # Success
    $!dialog.set-status("$sid successfully added");
  }
}

#--[menu entry sessions change]-------------------------------------------------
method change ( N-Object $parameter ) {
  self.init-fields(:!id-is-sensitive);
  $!sessions-dd.set-selection-changed( self, 'trap-select-session');

  # Fill the session drop down with the session ids and select the first one
  my @session-ids = $!sessions.get-session-ids.sort;
  if @session-ids.elems {
    $!sessions-dd.append(@session-ids);
  }

  with $!dialog .= new(
    :dialog-header('Change Session'), :!modal, :add-statusbar, :600width
  ) {
    # Add entries and dropdown widgets in the dialog
    .add-content( 'Session list', $!sessions-dd);
    .add-content( 'Session id', $!session-id);
    .add-content( 'Title', $!session-title, $!session-title-subst);
    .add-content( 'Icon', $!session-overlay, $!session-overlay-subst);
    .add-content( 'Picture', $!session-icon, $!session-icon-subst);

    # Add buttons to the dialog
#    .add-button( self, 'do-add-session', 'Add');
#    .add-button( self, 'do-rename-session', 'Rename');
    .add-button( self, 'do-change-session', 'Change');
    .add-button( $!dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-change-session ( ) {
  my SessionManager::Config $config .= instance;
  my Str $sid = $!session-id.get-text;
#  my Str $current-sid = $!sessions-dd.get-text;

  # Change the title, icon and overlay of the session
  $!sessions.set-session-title( $sid, $!session-title.get-text);
  $!sessions.set-session-icon(
    $sid, $config.set-picture($!session-icon.get-text)
  );
  $!sessions.set-session-overlay(
    $sid, $config.set-picture($!session-overlay.get-text)
  );

  # Success
  $!dialog.set-status("$sid successfully changed");
}

#--[menu entry sessions rename]-------------------------------------------------
method rename ( N-Object $parameter ) {
  self.init-fields(:id-only);
  $!sessions-dd.set-selection-changed( self, 'trap-select-session');

  # Fill the session drop down with the session ids and select the first one
  my @session-ids = $!sessions.get-session-ids.sort;
  if @session-ids.elems {
    $!sessions-dd.append(@session-ids);
  }

  with $!dialog .= new(
    :dialog-header('Rename Session'), :!modal, :add-statusbar, :600width
  ) {
    # Add entries and dropdown widgets in the dialog
    .add-content( 'Session list', $!sessions-dd);
    .add-content( 'Session id', $!session-id);
    .add-content( 'Title', $!session-title, $!session-title-subst);
    .add-content( 'Icon', $!session-overlay, $!session-overlay-subst);
    .add-content( 'Picture', $!session-icon, $!session-icon-subst);

    # Add buttons to the dialog
#    .add-button( self, 'do-add-session', 'Add');
    .add-button( self, 'do-rename-session', 'Rename');
#    .add-button( self, 'do-change-session', 'Change');
    .add-button( $!dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-rename-session ( ) {
  my Str $new-sid = $!session-id.get-text;
  my Str $current-sid = $!sessions-dd.get-text;
  if $new-sid eq $current-sid {
    $!dialog.set-status("$new-sid already defined");
  }

  else {
    $!sessions.rename-session( $current-sid, $new-sid);
    $!dialog.set-status("$current-sid successfully renamed to $new-sid");
  }
}

#--[menu entry sessions delete]-------------------------------------------------
method delete ( N-Object $parameter ) {
  self.init-fields(:id-only);
  $!sessions-dd.set-selection-changed( self, 'trap-select-session');

  # Fill the session drop down with the session ids and select the first one
  my @session-ids = $!sessions.get-session-ids.sort;
  if @session-ids.elems {
    $!sessions-dd.append(@session-ids);
  }

  with $!dialog .= new(
    :dialog-header('Delete Session'), :!modal, :add-statusbar, :600width
  ) {
    # Add entries and dropdown widgets in the dialog
    .add-content( 'Session list', $!sessions-dd);
    .add-content( 'Session id', $!session-id);
    .add-content( 'Title', $!session-title, $!session-title-subst);
    .add-content( 'Icon', $!session-overlay, $!session-overlay-subst);
    .add-content( 'Picture', $!session-icon, $!session-icon-subst);

    # Add buttons to the dialog
#    .add-button( self, 'do-add-session', 'Add');
    .add-button( self, 'do-delete-session', 'Delete');
#    .add-button( self, 'do-change-session', 'Change');
    .add-button( $!dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-delete-session ( ) {
  my Bool $actions-found = False;

  my Str $sid = $!sessions-dd.get-text;
  for $!sessions.get-group-ids($sid) -> $gid {
    $actions-found = ?$!sessions.get-group-actions( $sid, $gid);
    last if $actions-found;
  }

  if $actions-found {
    $!dialog.set-status(
      "There are still actions defined in groups. Clean first"
    );
  }

  else {
    $!sessions.delete-session($sid);

    my UInt $original-pos = $!sessions-dd.get-selection(:rows)[0];
note "$?LINE $original-pos";
    $!sessions-dd.splice( $original-pos, 1);
    $!dialog.set-status("Session '$sid' deleted");
  }
}

#--[menu entry groups]-------------------------------------------------------
method groups ( N-Object $parameter ) {
  with $!dialog .= new(
    :dialog-header('Modify Session Group'), :!modal, :add-statusbar
  ) {
    self.init-fields;

    # Call after dropdown fills
#    my Label $session-title .= new-label;# = self.make-session-title;
#    my Label $group-title .= new-label;# = self.make-group-title;

    # Trap changes in the sessions list
    $!sessions-dd.set-selection-changed( self, 'set-grouplist');

    # Trap changes in the group list
    $!groups-dd.set-selection-changed( self, 'set-grouptitle');

    # Fill the sessions list. Triggers the .set-grouplist() and
    # .set-grouptitle() call back routines.
    my @session-ids = $!sessions.get-session-ids.sort;
    $!sessions-dd.append(@session-ids);
    $!sessions-dd.select(@session-ids[0]);

    # Add entries and dropdown widgets
    .add-content( 'Current session', $!sessions-dd, $!session-title);
    .add-content( 'Current group', $!groups-dd, $!group-title);
    #.add-content( 'Group Title', $!group-title);

    # Add buttons
    .add-button( self, 'do-add-group', 'Add');
    .add-button( self, 'do-change-group', 'Set Title');
    .add-button( self, 'select-actions', 'Select Actions');
    .add-button( $!dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-add-group ( ) {
  my Str $sessionid = $!sessions-dd.get-text;

  # $new-group may be undefined when max is exceeded
  my $new-group = $!sessions.add-group( $sessionid, $!group-title.get-text);
  if ?$new-group {
    # Insert the group name in the dropdown and select the group
    $!groups-dd.append($new-group);
    $!groups-dd.select($new-group);

    $!dialog.set-status("$new-group is succesfully added");
  }

  else {
    $!dialog.set-status("maximum number of groups reached");
  }
}

#-------------------------------------------------------------------------------
# Changing the group is only a change for its title
method do-change-group ( ) {
  my Str $sessionid = $!sessions-dd.get-text;
  my Str $group = $!groups-dd.get-text;
  my Str $t = $!group-title.get-text;

  $!sessions.set-group-title( $sessionid, $group, $t);
  $!group-title-subst.set-text($!variables.substitute-vars($t));
  $!dialog.set-status("$group is succesfully changed");
}

#`{{
#-------------------------------------------------------------------------------
method delete-group ( N-Object $parameter, ) {
  note "Delete group";
}
}}

#--[menu entry select actions]--------------------------------------------------
method select-actions ( ) {
#  my Actions $actions .= new;

#  my DropDown $groups-dd .= new;
#  $groups-dd.set-events;

#  my DropDown $sessions-dd .= new;
#  $sessions-dd.set-events;

#  my Label $grouptitle .= new-label;
#  my Label $sessiontitle .= new-label;

#  self.init-fields;
#`{{
  my Label $session-title .= new-label;# .= new-label;
#  $session-title.set-text($!session-title.get-text);
  my Label $group-title .= new-label;# .= new-label;
#  $group-title.set-text($!group-title.get-text);

#    my ListBox $sessions-actions-list;
#  my ListBox $all-actions-list;
}}
  with $!actions-view .= new(:multi-select) {
    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

#    .set-selection-changed( self, 'set-input-fields');

    .append($!actions.get-action-ids.sort: {$^a.lc leg $^b.lc});
#    .append($!actions.get-action-idss[^2]);
  }

#`{{
  # Trap changes in the sessions list
  $!sessions-dd.set-selection-changed( self, 'set-grouplist');

  # Trap changes in the group list
  $!groups-dd.set-selection-changed( self, 'set-grouptitle');

  # Fill the sessions list.
  my @session-ids = $!sessions.get-session-ids.sort;
  $!sessions-dd.append(@session-ids);
  $!sessions-dd.select(@session-ids[0]);

  # Create the listbox to list all actions.
#  $all-actions-list .= new(:multi);
#  my ScrolledWindow $sw2 = $all-actions-list.set-list(
#    [|$actions.get-action-ids]
#  );
}}

  with $!dialog .= new(
    :dialog-header('Modify Session Actions'), :!modal, :add-statusbar
  ) {

    # Fill the groups list.
    #$groups-dd.append(|$!sessions.get-group-ids(@session-ids[0]).sort);

    # Call the callback routine once to fillout the titles of session and group
    # and make the sessions actions list visible in the actions listbox
#    self.set-grouplist(
#      :$sessions-dd, :$groups-dd, :$sessiontitle, :$grouptitle, 
#      :$all-actions-list
#    );

#note "$?LINE $!session-title-subst
    # Add entries and dropdown widgets
    .add-content( 'Current session', 3, $!session-title-subst);
    .add-content( 'Current group', 3, $!group-title-subst);
    .add-content( 'All Actions list', 3, $!actions-view);

    my Entry $search .= new-entry;
    with my Button $search-button .= new-button {
      .set-label('Select from list');
      .register-signal( self, 'select-from-list', 'clicked', :$search);
    }
    with my Button $reset-button .= new-button {
      .set-label('Reset search');
      .register-signal( self, 'reset-list', 'clicked', :$search);
    }
    my Box $bt-box .= new-box( GTK_ORIENTATION_HORIZONTAL, 10);
    $bt-box.append($search-button);
    $bt-box.append($reset-button);
    my Label $strut1 .= new-label;
    $bt-box.append($strut1);
    .add-content( 'Search in list', $search, $bt-box);

    # Add buttons
    # Show a dialog to add an action
    .add-button( self, 'add-actions', 'Add Actions');

    # Show a dialog to modify an action
    .add-button( self, 'remove-actions', 'Remove Actions');
    # Show a dialog to delete an action

#    .add-button( self, 'clear-actions', 'Deselect All Actions');

    # Finish dialog
    .add-button( self, 'set-actions', 'Done');

    .set-size-request( 800, 800);
    .show-dialog;
  }
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
# When leaving the dialog (on Done), set the sessions actions list from the
# selected entries of the total actions list
method set-actions ( ) {
  my Str $c-session = $!sessions-dd.get-text;
  my Str $c-group = $!groups-dd.get-text;
#  $!sessions.set-group-actions( $c-session, $c-group, $listbox.get-list);

  # Remove dialog
  $!dialog.destroy-dialog;
}

#-------------------------------------------------------------------------------
method add-actions ( ) {
  my Str $sessionid = $!sessions-dd.get-text;
  my Str $groupname = $!groups-dd.get-text // '';
  my @selections = $!actions-view.get-selection;
  $!sessions.add-actions( $sessionid, $groupname, |@selections);

  for $!actions-view.get-selection(:rows) -> $pos {
    $!actions-view.splice( $pos, 1, @selections.shift);
  }
}

#-------------------------------------------------------------------------------
method remove-actions ( ) {
  my Str $sessionid = $!sessions-dd.get-text;
  my Str $groupname = $!groups-dd.get-text // '';
  my @selections = $!actions-view.get-selection;
  $!sessions.remove-actions( $sessionid, $groupname, |@selections);

  for $!actions-view.get-selection(:rows) -> $pos {
    $!actions-view.splice( $pos, 1, @selections.shift);
  }
}

#`{{
#-------------------------------------------------------------------------------
method modify-action ( ) {
  my SessionManager::Gui::Actions $gui-actions .= instance;
  my Str $action-id = $!actions-view.get-selection()[0] // '';
  if ?$action-id {
    $gui-actions.modify(:target-id($action-id));
  }

  else {
    $!dialog.set-status('Please select an action id from the list');
  }

#`{{
  if ?$action-id {
    my Str $c-session = $sessions-dd.get-text;
    my Str $c-group = $groups-dd.get-text;
    $!sessions.set-group-actions( $c-session, $c-group, $action-id);
    $listbox.reset-list($!sessions.get-group-actions( $c-session, $c-group));
  }
}}
}
}}

#-------------------------------------------------------------------------------
method set-grouplist ( ) {
  $!session-title.set-text(
    $!sessions.get-session-title($!sessions-dd.get-text)
  );

  my Str $sessionid = $!sessions-dd.get-text;
#note "$?LINE {$sessionid//'-'}";
#  return unless ?$sessionid;
#  $!session-title.set-text($!sessions.get-session-title($sessionid));

  # Remove first before showing. Otherwise it only grows.
  $!groups-dd.remove(0..^$!groups-dd.get-n-items());
  $!groups-dd.append($!sessions.get-group-ids($sessionid).sort);
  $!groups-dd.set-selection(0);

  if ?$!actions-view and $!actions-view.is-valid {
    my @selections = $!actions.get-action-ids.sort: {$^a.lc leg $^b.lc};
    for ^$!actions-view.get-n-items -> $pos {
      $!actions-view.splice( $pos, 1, @selections.shift);
    }
  }
}

#-------------------------------------------------------------------------------
method set-grouptitle ( ) {
#  self.make-group-label(:label($group-title));
  $!group-title.set-text(
    $!sessions.get-group-title(
      $!sessions-dd.get-text, $!groups-dd.get-text
    )
  );

#  my Str $sessionid = $!sessions-dd.get-text;
#  my Str $groupname = $!groups-dd.get-text // '';
#  $!group-title.set-text($!sessions.get-group-title( $sessionid, $groupname));

#  my Str $group-name = $!groups-dd.get-text;
#  $!group-title.set-text($!sessions.get-group-title( $sessionid, $group-name));
#`{{
  # Select the items found in this group
  if ?$!actions-view {
    my @group-actions;
    for @($!sessions.get-group-actions( $sessionid, $groupname)) -> $ga {
      @group-actions.push: $!actions-view.find($ga);
    }
    $!actions-view.set-selection(@group-actions);
  }
}}

#`{{
  $all-actions-list.reset-list(
    $!sessions.get-group-actions( $session-id, $group-name)
  ) if ?$all-actions-list;
  $all-actions-list.append(
    $!sessions.get-group-actions( $session-id, $group-name)
  ) if ?$all-actions-list;
}}
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

  with $!session-overlay .= new-entry {
    .set-sensitive(!$id-only);
#    .set-has-tooltip(True);
  }

  $!session-title-subst .= new-label;
  $!session-title-subst.set-halign(GTK_ALIGN_START);

  $!session-icon-subst .= new-label;
  $!session-icon-subst.set-halign(GTK_ALIGN_START);

  $!session-overlay-subst .= new-label;
  $!session-overlay-subst.set-halign(GTK_ALIGN_START);

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

  $t = $!sessions.get-session-overlay($sid);
  $!session-overlay.set-text($t);
  $!session-overlay-subst.set-text($!variables.substitute-vars($t));
}

#-------------------------------------------------------------------------------
method setup-item ( ) {
  my Label $action-id = self.make-label;
  my Label $action-value = self.make-label;
  my Image $used = self.make-image;

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
  self.set-text-at( 2, 0, $name, $grid);
  self.set-text-at( 2, 1, $action-object<t>//'', $grid);

  my Str $sessionid = $!sessions-dd.get-text;
  my Str $groupname = $!groups-dd.get-text // '';
  my Bool $name-inuse = $!sessions.is-action-in-use-in-session(
    $sessionid, $groupname, $name
  );

  # Select the items found in this group
#  my @group-actions = $!sessions.get-group-actions( $sessionid, $groupname);
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

#-------------------------------------------------------------------------------
method make-label ( --> Label ) {
  with my Label $label .= new-label {
    .set-halign(GTK_ALIGN_START);
    .set-justify(GTK_JUSTIFY_LEFT);
    .set-hexpand(True);
  }

  $label
}

#-------------------------------------------------------------------------------
method make-image ( --> Image ) {
  with my Image $image .= new-image {
    .set-size-request( 40, 40);
    .set-margin-end(10);
  }

  $image
}

#-------------------------------------------------------------------------------
method set-text-at ( Int $row, Int $col, Str $text, Gnome::Gtk4::Grid $grid ) {
  my Label() $label = $grid.get-child-at( $row, $col);
  $label.set-text($text);
}

#-------------------------------------------------------------------------------
method set-image-at (
  Int $row, Int $col, Str $color, Str $name,
  Bool $name-inuse, Gnome::Gtk4::Grid $grid
) {
  my Str $on-off = $name-inuse ?? 'on' !! 'off';
  my Image() $used = $grid.get-child-at( $row, $col);
  my Str $resource = $color ~ '-' ~ $on-off ~ '-256.png';
  $used.set-from-file(%?RESOURCES{$resource});
}

#`{{
#-------------------------------------------------------------------------------
method selection-changed ( UInt $pos, @selections ) {
  my Str $name = @selections[0];
  $!variable-name.set-text($name);
  my Str $value = $!variables.get-variable($name);
  $!variable-spec.set-text($value);
}
}}