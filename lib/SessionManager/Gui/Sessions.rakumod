v6.d;

use YAMLish;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;

use Gnome::Gtk4::Entry:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Sessions;

constant ConfigPath = '/Config/sessions.yaml';
my SessionManager::Gui::Sessions $instance;

constant DropDown = GnomeTools::Gtk::DropDown;
constant Entry = Gnome::Gtk4::Entry;

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
# Calls from menubar entries
#-------------------------------------------------------------------------------
method sessions-create-modify (
  N-Object $parameter, :extra-data($actions-object)
) {
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Modify Variable'), :add-statusbar
  ) {
    my DropDown $groups-dd .= new;
    my Entry $grouptitle-e .= new-entry;
    my Entry $sessiontitle-e .= new-entry;

    # Fill the sessions list
    my DropDown $sessions-dd .= new;
    $sessions-dd.set-selection($!sessions.keys.sort);
    $sessions-dd.trap-dropdown-changes(
      self, 'set-grouplist', :$sessions-dd, :$groups-dd,
      :$sessiontitle-e, :$grouptitle-e
    );

    # Get the currently selected sessions name
    my Str $session-name = $sessions-dd.get-text;

    # Set title text
    $sessiontitle-e.set-text($!sessions{$session-name}<title> // '');
note "$?LINE Session name: $session-name, ";

#    self.set-grouplist( N-Object, :$sessions-dd, :$groups-dd, :$grouptitle-e);
    $groups-dd.trap-dropdown-changes(
      self, 'set-group-title', :$groups-dd, :$grouptitle-e
    );

#    $sessions-dd.register-signal( self, 'set-groups', 'selected', :$groups-dd);
#!!!!!!!!!!!!!!!!!!!!!!!!!    
#    $sessions-dd.set-selection($!$sessions.keys.sort);
    .add-content( 'Session title', $sessiontitle-e);
    .add-content( 'Session list', $sessions-dd);
    .add-content( 'Group title', $grouptitle-e);
    .add-content( 'Groups in session', $groups-dd);
#`{{
    .add-content( 'Groups list', my Entry $vname .= new-entry);
    .add-content( 'Actions list', my Entry $vspec .= new-entry);

    .add-button(
      self, 'do-rename-session', 'Rename',
      :$dialog, :$vname, :$vspec, :$actions-object
    );
  }}
    .add-button(
      self, 'do-add-session', 'Add', :$dialog,
    );

    .add-button(
      self, 'do-modify-session', 'Modify', :$dialog, 
    );

    .add-button(
      self, 'do-add-group', 'Add Group', :$dialog, 
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    $sessions-dd.register-signal(
      self, 'set-data', 'row-selected',
    );

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method set-grouplist (
  N-Object $, DropDown :$sessions-dd, DropDown :$groups-dd,
  Entry :$sessiontitle-e, Entry :$grouptitle-e
) {
  my Str $session-name = $sessions-dd.get-text;
note "$?LINE Session name: $session-name, ", $!sessions{$session-name}.keys.grep(/group/);
  $groups-dd.set-selection($!sessions{$session-name}.keys.grep(/^group/).sort);
  $grouptitle-e.set-text(
    $!sessions{$session-name}{$groups-dd.get-text}<title> // ''
  );

    $sessiontitle-e.set-text($!sessions{$session-name}<title> // '');
}

#------------------------------------------------------------------------------
method set-grouptitle (
  N-Object $, DropDown :$sessions-dd, DropDown :$groups-dd, Entry :$grouptitle-e
) {
  my Str $session-name = $sessions-dd.get-text;
note "$?LINE S name: $session-name, ", $!sessions{$session-name}.keys.grep(/group/);
   $grouptitle-e.set-text($!sessions{$session-name}<title>//'');
}

#-------------------------------------------------------------------------------
method sessions-delete (
  N-Object $parameter, :extra-data($actions-object)
) {
}
