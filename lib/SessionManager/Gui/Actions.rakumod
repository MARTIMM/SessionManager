use v6.d;

use SessionManager::ActionData;

use Digest::SHA256::Native;
use YAMLish;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Actions;

constant ConfigPath = '/Config/actions.yaml';

#-------------------------------------------------------------------------------
my $instance;

has Hash $!data-ids;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!data-ids = %();
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Actions ) {
  $instance //= self.bless;

  $instance
}

#-------------------------------------------------------------------------------
method add-action ( Hash:D $raw-action, Str :$id = '' --> Str ) {
  my SessionManager::ActionData $action-data;
  $action-data .= new( :$raw-action, :$id);
  $!data-ids{$action-data.id} = $action-data;
  $action-data.id
}

#-------------------------------------------------------------------------------
# Only in action reference files
multi method add-actions ( Hash:D $raw-actions ) {
  for $raw-actions.keys -> $id {
    self.add-action( $raw-actions{$id}, :$id);
  }
}

#-------------------------------------------------------------------------------
# Only found in config file and parts files
multi method add-actions ( Array:D $raw-actions ) {
  for @$raw-actions -> $action {
    self.add-action($action);
  }
}

#-------------------------------------------------------------------------------
# Read from action reference files
method add-from-yaml ( Str:D $path ) {
  die "File $path not found or unreadable" unless $path.IO.r;

  self.add-actions(load-yaml($path.IO.slurp));
}

#-------------------------------------------------------------------------------
method save ( ) {
#  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($!data-ids));
  note "$?LINE ", $!data-ids;
}

#-------------------------------------------------------------------------------
method get-action ( Str:D $id is copy --> SessionManager::ActionData ) {
  if $!data-ids{$id}:exists {
    $!data-ids{$id}
  }

  else {
    # If action data isn't found, try $id as if it was a tooltip
    # string. Those are taken when no id was found and converted into sha256
    # strings in SessionManager::ActionData.
    $id = sha256-hex($id);
    if $!data-ids{$id}:exists {
      $!data-ids{$id}
    }

    else {
      SessionManager::ActionData
    }
  }
}

#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method actions-create ( N-Object $parameter ) {
  note "$?LINE";

  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Create Action')
  ) {

    
#`{{
    my Str $current-root = $!config.get-current-root;

    # Make a string list to be used in a combobox (dropdown)
    my GnomeTools::Gtk::DropDown $container-dd .= new;
    $container-dd.fill-containers(
      $!config.get-current-container, $current-root, :skip-default
    );

    my GnomeTools::Gtk::DropDown $roots-dd;
    if $*multiple-roots {
      $roots-dd .= new;
      $roots-dd.fill-roots($!config.get-current-root);

      # Show dropdown
      .add-content( 'Select a root', $roots-dd);

      # Set a handler on the container list to change the category list
      # when an item is selected.
      $roots-dd.trap-root-changes( $container-dd, :skip-default);
    }

    # Show entry for input
    .add-content( 'Select container to delete', $container-dd);

    # Buttons to delete the container or cancel
    .add-button(
      self, 'do-container-delete', 'Delete',
      :$dialog, :$container-dd, :$roots-dd
    );
    .add-button( $dialog, 'destroy-dialog', 'Cancel');
}}

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-create-action (
  GnomeTools::Gtk::Dialog :$dialog,
  GnomeTools::Gtk::DropDown :$container-dd,
  GnomeTools::Gtk::DropDown :$roots-dd
) {
  my Bool $sts-ok = False;
  my Str $root-dir;


#`{{
  if $*multiple-roots {
    $root-dir = $roots-dd.get-dropdown-text;
  }

  else {
    $root-dir = $!config.get-current-root;
  }

  my Str $container = $container-dd.get-dropdown-text;
  if not $!config.delete-container( $container, $root-dir) {
    $dialog.set-status("Container $container not empty");
  }

  else {
    $!sidebar.fill-sidebar;
    $sts-ok = True;
  }
}}

  $dialog.destroy-dialog if $sts-ok;
}


#-------------------------------------------------------------------------------
method actions-modify ( N-Object $parameter ) {
  note "$?LINE";
}

#-------------------------------------------------------------------------------
method actions-delete ( N-Object $parameter ) {
  note "$?LINE";
}

