use v6.d;

use SessionManager::ActionData;

use Digest::SHA256::Native;
use YAMLish;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;

use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::ListBox:api<2>;
use Gnome::Gtk4::ListBoxRow:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Actions;

constant ConfigPath = '/Config/actions.yaml';

constant Entry = Gnome::Gtk4::Entry;
constant ListBox = Gnome::Gtk4::ListBox;
constant ListBoxRow = Gnome::Gtk4::ListBoxRow;
constant Label = Gnome::Gtk4::Label;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;

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
  my Hash $raw-actions = %();
  for $!data-ids.keys -> $id {
    $raw-actions{$id} = $!data-ids{$id}.raw-action;
  }

  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($raw-actions));
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
# Substitute changed variable in the raw actions Hash.
method subst-vars ( Str $original-var, Str $new-var ) {
  for $!data-ids.keys -> $id {
    $!data-ids{$id}.subst-vars( $original-var, $new-var);
  }
}

#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method actions-create-modify ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Add Variable'), :add-statusbar
  ) {
    #my GnomeTools::Gtk::DropDown $variables-dd .= new;
    #$variables-dd.set-selection($!variables.keys.sort);
    my ListBox $variables-lb .= new-listbox;
    for $!data-ids.keys.sort -> $id {
      with my Label $l .= new-with-mnemonic($id) {
        .set-justify(GTK_JUSTIFY_LEFT);
        .set-halign(GTK_ALIGN_START);
      }
      $variables-lb.append($l);
    }

    with my ScrolledWindow $sw .= new-scrolledwindow {
      .set-child($variables-lb);
      .set-size-request( 400, 200);
    }

    .add-content( 'Actions list', $sw);
    .add-content( 'Action id', my Entry $action-id .= new-entry);
    .add-content( 'Title', my Entry $aspec-title .= new-entry);
    .add-content( 'Command', my Entry $aspec-cmd .= new-entry);
    .add-content( 'Path', my Entry $aspec-path .= new-entry);
    .add-content( 'Wait', my Entry $aspec-wait .= new-entry);
    .add-content( 'Logging', my Entry $aspec-log .= new-entry);
    .add-content( 'Icon', my Entry $aspec-icon .= new-entry);
    .add-content( 'Picture', my Entry $aspec-pic .= new-entry);
#    .add-content( 'Environment', my Entry $aspec-env .= new-entry);
#    .add-content( 'Variables', my Entry $aspec-vars .= new-entry);
#    .add-content( '', my Entry $aspec- .= new-entry);

    .add-button( self, 'do-create-act', 'Create', :$dialog, :$action-id, :$aspec-title, :$aspec-cmd, :$aspec-path, :$aspec-wait, :$aspec-log,
      :$aspec-icon, :$aspec-pic
    );
    .add-button( self, 'do-modify-act', 'Modify', :$dialog, :$action-id, :$aspec-title, :$aspec-cmd, :$aspec-path, :$aspec-wait, :$aspec-log,
      :$aspec-icon, :$aspec-pic
    );
    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    $variables-lb.register-signal(
      self, 'set-data', 'row-selected', :$dialog, :$action-id, :$aspec-title, 
      :$aspec-cmd, :$aspec-path, :$aspec-wait, :$aspec-log,
      :$aspec-icon, :$aspec-pic
    );

    .show-dialog;
  }
#`{{
}}
    
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

}

#-------------------------------------------------------------------------------
method do-create-act (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id, Entry :$aspec-title,
  Entry :$aspec-cmd, Entry :$aspec-path, Entry :$aspec-wait, Entry :$aspec-log,
  Entry :$aspec-icon, Entry :$aspec-pic
) {
  my Bool $sts-ok = False;
  my Str $root-dir;

  if !$action-id {
    $dialog.set-status('An action id may not be empty');
  }

  else {
    $sts-ok = True;
  }
  
  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method do-modify-act (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id, Entry :$aspec-title,
  Entry :$aspec-cmd, Entry :$aspec-path, Entry :$aspec-wait, Entry :$aspec-log,
  Entry :$aspec-icon, Entry :$aspec-pic
) {
  my Bool $sts-ok = False;
  my Str $root-dir;

  $dialog.destroy-dialog if $sts-ok;
}



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

#-------------------------------------------------------------------------------
method set-data( ListBoxRow() $row, GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id, Entry :$aspec-title,
  Entry :$aspec-cmd, Entry :$aspec-path, Entry :$aspec-wait, Entry :$aspec-log,
  Entry :$aspec-icon, Entry :$aspec-pic) {
  my Label() $l = $row.get-child;
  my Str $id = $action-id.set-text($l.get-text);

#  .set-text($!variables{$l.get-text});
}

#-------------------------------------------------------------------------------
method actions-delete ( N-Object $parameter ) {
  note "$?LINE";
}

