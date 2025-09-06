v6.d;

use YAMLish;

use SessionManager::Gui::Actions;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListBox;

use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
#use Gnome::Gtk4::ListBox:api<2>;
#use Gnome::Gtk4::ListBoxRow:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Sessions;

constant ConfigPath = '/Config/sessions.yaml';
my SessionManager::Gui::Sessions $instance;

constant Dialog = GnomeTools::Gtk::Dialog;
constant DropDown = GnomeTools::Gtk::DropDown;
constant Entry = Gnome::Gtk4::Entry;
constant Actions = SessionManager::Gui::Actions;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
#constant ListBoxRow = Gnome::Gtk4::ListBoxRow;
constant ListBox = GnomeTools::Gtk::ListBox;

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
method sessions-create-modify (
  N-Object $parameter, :extra-data($actions-object)
) {
  my Actions $actions .= instance;

  with my Dialog $dialog .= new(
    :dialog-header('Modify Session'), :add-statusbar
  ) {
    my DropDown $groups-dd .= new;
    my DropDown $sessions-dd .= new;
    my Entry $grouptitle-e .= new-entry;
    my Entry $sessiontitle-e .= new-entry;

    # Trap changes in the sessions list
    $sessions-dd.trap-dropdown-changes(
      self, 'set-grouplist', :$sessions-dd, :$groups-dd,
      :$sessiontitle-e, :$grouptitle-e
    );

    # Trap changes in the group list
    $groups-dd.trap-dropdown-changes(
      self, 'set-grouptitle', :$sessions-dd, :$groups-dd, :$grouptitle-e
    );

    # Fill the sessions list. Triggers the .set-grouplist() and
    # .set-grouptitle() call back routines.
    $sessions-dd.set-selection($!sessions.keys.sort);

    my ListBox $actions-list .= new(:multi);
    my ScrolledWindow $sw = $actions-list.set-list((|$actions.get-ids));

    # Add entries and dropdown widgets
    .add-content( 'Current session', $sessions-dd, :2columns);
    .add-content( 'Session title', $sessiontitle-e, :2columns);
    .add-content( 'Current group', $groups-dd, :2columns);
    .add-content( 'Group title', $grouptitle-e, :2columns);
    .add-content( 'Actions list', $sw, :2rows);

    # Add buttons
#    .add-button(
#      self, 'save-sessiontitle', 'Set session title',
#      :$dialog, :$sessiontitle-e, :$sessions-dd
#    );

    .add-button(
      self, 'save-session', 'Save session',
      :$dialog, :$sessions-dd, :$groups-dd, :$sessiontitle-e, :$grouptitle-e
    );

    .add-button(
      self, 'do-add-session', 'Add', :$dialog,
    );

    .add-button(
      self, 'do-modify-session', 'Modify', :$dialog, 
    );

    .add-button(
      self, 'do-add-group', 'Add Group', :$dialog, 
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

#    $sessions-dd.register-signal( self, 'set-data', 'row-selected');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method set-grouplist (
  N-Object $, DropDown :$sessions-dd, DropDown :$groups-dd,
  Entry :$sessiontitle-e, Entry :$grouptitle-e
) {
  my Str $session-name = $sessions-dd.get-text;
  $groups-dd.set-selection($!sessions{$session-name}.keys.grep(/^group/).sort);

  my Str $group-name = $groups-dd.get-text;
  $grouptitle-e.set-text($!sessions{$session-name}{$group-name}<title> // '');

  $sessiontitle-e.set-text($!sessions{$session-name}<title> // '');
}

#------------------------------------------------------------------------------
method set-grouptitle (
  N-Object $, DropDown :$sessions-dd, DropDown :$groups-dd, Entry :$grouptitle-e
) {
  my Str $session-name = $sessions-dd.get-text;
  my Str $group-name = $groups-dd.get-text;
  $grouptitle-e.set-text($!sessions{$session-name}{$group-name}<title> // '');
}

#-------------------------------------------------------------------------------
method save-session (
  Dialog :$dialog, DropDown :$sessions-dd, DropDown :$groups-dd,
  Entry :$sessiontitle-e, Entry :$grouptitle-e,
) {
  my Str $session-name = $sessions-dd.get-text;
  $!sessions{$session-name}<title> = $sessiontitle-e.get-text;

  my Str $group-name = $groups-dd.get-text;
  $!sessions{$session-name}{$group-name}<title> = $grouptitle-e.get-text;
}

#-------------------------------------------------------------------------------
method select-action (
#  ListBoxRow() $row, 
#  Dialog :$dialog, DropDown :$sessions-dd, DropDown :$groups-dd,
#  Entry :$sessiontitle-e, Entry :$grouptitle-e,
) {
}

#-------------------------------------------------------------------------------
method sessions-delete (
  N-Object $parameter, :extra-data($actions-object)
) {
}
