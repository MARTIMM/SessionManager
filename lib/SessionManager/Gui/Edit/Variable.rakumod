use v6.d;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Edit::Variable;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
}

#-------------------------------------------------------------------------------
method variable-create ( N-Object $parameter ) {
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
method do-create-variable (
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
method variable-modify ( N-Object $parameter ) {
  note "$?LINE";
}

#-------------------------------------------------------------------------------
method variable-delete ( N-Object $parameter ) {
  note "$?LINE";
}

