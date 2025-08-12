v6.d;

use YAMLish;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Sessions;

constant ConfigPath = '/Config/sessions.yaml';
my SessionManager::Gui::Sessions $instance;

constant DropDown = GnomeTools::Gtk::DropDown;

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
    
    my DropDown $sessions-dd .= new;
    $sessions-dd.set-selection($!sessions.keys.sort);
    $sessions-dd.register-signal( self, 'set-groups', 'selected', :$groups-dd);
#!!!!!!!!!!!!!!!!!!!!!!!!!    
#    $sessions-dd.set-selection($!$sessions.keys.sort);
    .add-content( 'Session list', $sessions-dd);
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
method set-groups ( DropDown :$groups-dd ) {

}

#-------------------------------------------------------------------------------
method sessions-delete (
  N-Object $parameter, :extra-data($actions-object)
) {
}
