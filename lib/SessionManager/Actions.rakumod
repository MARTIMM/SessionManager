use v6.d;

use SessionManager::ActionData;

use Digest::SHA256::Native;
use YAMLish;

#`{{
use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListBox;

use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Switch:api<2>;
#use Gnome::Gtk4::ListBox:api<2>;
#use Gnome::Gtk4::ListBoxRow:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
}}

#-------------------------------------------------------------------------------
unit class SessionManager::Actions;

constant ConfigPath = '/Config/actions.yaml';

#`{{
constant Entry = Gnome::Gtk4::Entry;
constant Switch = Gnome::Gtk4::Switch;
constant ListBox = GnomeTools::Gtk::ListBox;
#constant ListBoxRow = Gnome::Gtk4::ListBoxRow;
constant Label = Gnome::Gtk4::Label;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
}}

#-------------------------------------------------------------------------------
#my $instance;

my Hash $data-ids = %();
#has Str $!original-id;
#has ListBoxRow $!original-row;
#`{{
#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $data-ids = %();
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Actions ) {
  $instance //= self.bless;

  $instance
}
}}

#-------------------------------------------------------------------------------
method add-action ( Hash:D $raw-action, Str :$id = '' --> Str ) {
  my SessionManager::ActionData $action-data;
  $action-data .= new;
  $action-data.init-action( :$raw-action, :$id);
  $data-ids{$action-data.id} = $action-data;
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
  for $data-ids.keys -> $id {
    $raw-actions{$id} = $data-ids{$id}.raw-action;
  }

  ($*config-directory ~ ConfigPath).IO.spurt(save-yaml($raw-actions));
}

#-------------------------------------------------------------------------------
method load ( ) {
  if ($*config-directory ~ ConfigPath).IO.r {
    my Hash $raw-actions = load-yaml(
      ($*config-directory ~ ConfigPath).IO.slurp
    );

    for $raw-actions.keys -> $id {
      self.add-action( $raw-actions{$id}, :$id);
    }
  }
}

#-------------------------------------------------------------------------------
method get-action-ids ( --> Seq ) {
  $data-ids.keys
}

#-------------------------------------------------------------------------------
method get-raw-action ( Str:D $action-id --> Hash ) {
  $data-ids{$action-id}.raw-action
}

#-------------------------------------------------------------------------------
method get-action ( Str:D $id is copy --> SessionManager::ActionData ) {
  if $data-ids{$id}:exists {
    $data-ids{$id}
  }

  else {
    # If action data isn't found, try $id as if it was a tooltip
    # string. Those are taken when no id was found and converted into sha256
    # strings in SessionManager::ActionData.
    $id = sha256-hex($id);
    if $data-ids{$id}:exists {
      $data-ids{$id}
    }

    else {
      SessionManager::ActionData
    }
  }
}

#-------------------------------------------------------------------------------
method rename-action ( Str:D $id, Str:D $new-id ) {
  $data-ids{$new-id} = $data-ids{$id}:delete;
}
 
#-------------------------------------------------------------------------------
method modify-action ( Str:D $id, Hash $raw-action ) {
  my SessionManager::ActionData $action-data = $data-ids{$id};
  $action-data.init-action( :$id, :$raw-action);
}

#-------------------------------------------------------------------------------
# Substitute changed variable in the raw actions Hash.
method subst-vars ( Str $original-var, Str $new-var ) {
  for $data-ids.keys -> $id {
    $data-ids{$id}.subst-vars( $original-var, $new-var);
  }
}













=finish
#-------------------------------------------------------------------------------
# Calls from menubar entries
#-------------------------------------------------------------------------------
method actions-create ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Modify Action'), :add-statusbar
  ) {
    my Entry $action-id .= new-entry;
    my Entry $aspec-title .= new-entry;
    my Entry $aspec-cmd .= new-entry;
    my Entry $aspec-path .= new-entry;
    my Entry $aspec-wait .= new-entry;
    my Switch $aspec-log .= new-switch;
    my Entry $aspec-icon .= new-entry;
    my Entry $aspec-pic .= new-entry;

    # Set placeholder texts when optional
    $aspec-path.set-placeholder-text('optional');
    $aspec-wait.set-placeholder-text('optional');
    $aspec-icon.set-placeholder-text('optional');
    $aspec-pic.set-placeholder-text('optional');
    
    my ListBox $listbox;
    my ScrolledWindow $scrolled-listbox;
    ( $listbox, $scrolled-listbox) = self.scrollable-list(
      :$dialog, :$action-id, :$aspec-title, :$aspec-cmd, :$aspec-path,
      :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic
    );

    .add-content( 'Current actions', $scrolled-listbox, :4columns);
    .add-content( 'Action id', $action-id, :4columns);
    .add-content( 'Title', $aspec-title, :4columns);
    .add-content( 'Command', $aspec-cmd, :4columns);
    .add-content( 'Path', $aspec-path, :4columns);
    .add-content( 'Wait', $aspec-wait, :4columns);
    .add-content( 'Logging', $aspec-log);
    .add-content( 'Icon', $aspec-icon, :4columns);
    .add-content( 'Picture', $aspec-pic, :4columns);
#    .add-content( 'Environment', my Entry $aspec-env .= new-entry);
#    .add-content( 'Variables', my Entry $aspec-vars .= new-entry);
#    .add-content( '', my Entry $aspec- .= new-entry);

    .add-button( self, 'do-create-act', 'Create', :$dialog, :$action-id,
      :$aspec-title, :$aspec-cmd, :$aspec-path, :$aspec-wait, :$aspec-log,
      :$aspec-icon, :$aspec-pic
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }

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
  Entry :$aspec-cmd, Entry :$aspec-path, Entry :$aspec-wait, Switch :$aspec-log,
  Entry :$aspec-icon, Entry :$aspec-pic
) {
  my Bool $sts-ok = False;
  my Str $id = $action-id.get-text;

  if !$id {
    $dialog.set-status('The action id may not be empty');
  }

  elsif $id ~~ any(|$data-ids.keys) {
    $dialog.set-status('This action id is already defined');
  }

  else {
    my Hash $raw-action = %();
    $raw-action<t> = $aspec-title.get-text;
    $raw-action<c> = $aspec-cmd.get-text;
    $raw-action<o> = $aspec-icon.get-text;
    $raw-action<i> = $aspec-pic.get-text;
    $raw-action<l> = $aspec-log.get-state;
    $raw-action<w> = $aspec-wait.get-text.Int;
    $raw-action<p> = $aspec-path.get-text;
    self.add-action( $raw-action, :$id);
    $sts-ok = True;
  }

#  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method actions-modify ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Modify Action'), :add-statusbar
  ) {
    my Entry $action-id .= new-entry;
    my Entry $aspec-title .= new-entry;
    my Entry $aspec-cmd .= new-entry;
    my Entry $aspec-path .= new-entry;
    my Entry $aspec-wait .= new-entry;
    my Switch $aspec-log .= new-switch;
    my Entry $aspec-icon .= new-entry;
    my Entry $aspec-pic .= new-entry;

    # Set placeholder texts when optional
    $aspec-path.set-placeholder-text('optional');
    $aspec-wait.set-placeholder-text('optional');
    $aspec-icon.set-placeholder-text('optional');
    $aspec-pic.set-placeholder-text('optional');
    
    my ListBox $listbox;
    my ScrolledWindow $scrolled-listbox;
    ( $listbox, $scrolled-listbox) = self.scrollable-list(
      :$dialog, :$action-id, :$aspec-title, :$aspec-cmd, :$aspec-path,
      :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic
    );

    .add-content( 'Current actions', $scrolled-listbox, :4columns);
    .add-content( 'Action id', $action-id, :4columns);
    .add-content( 'Title', $aspec-title, :4columns);
    .add-content( 'Command', $aspec-cmd, :4columns);
    .add-content( 'Path', $aspec-path, :4columns);
    .add-content( 'Wait', $aspec-wait, :4columns);
    .add-content( 'Logging', $aspec-log);
    .add-content( 'Icon', $aspec-icon, :4columns);
    .add-content( 'Picture', $aspec-pic, :4columns);
#    .add-content( 'Environment', my Entry $aspec-env .= new-entry);
#    .add-content( 'Variables', my Entry $aspec-vars .= new-entry);
#    .add-content( '', my Entry $aspec- .= new-entry);

    .add-button( self, 'do-modify-act', 'Modify', :$dialog, :$listbox,
      :$aspec-title, :$aspec-cmd, :$aspec-path, :$aspec-wait,
      :$aspec-log, :$aspec-icon, :$aspec-pic
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');
#`{{
    $variables-lb.register-signal(
      self, 'set-data', 'row-selected', :$dialog, :$action-id, :$aspec-title, 
      :$aspec-cmd, :$aspec-path, :$aspec-wait, :$aspec-log,
      :$aspec-icon, :$aspec-pic
    );
}}
    .show-dialog;
  }

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
method do-modify-act (
  GnomeTools::Gtk::Dialog :$dialog, ListBox :$listbox,
  Entry :$aspec-title, Entry :$aspec-cmd,
  Entry :$aspec-path, Entry :$aspec-wait, Switch :$aspec-log,
  Entry :$aspec-icon, Entry :$aspec-pic
) {
  my Bool $sts-ok = False;

  my Hash $raw-action = %();
  $raw-action<t> = $aspec-title.get-text;
  $raw-action<c> = $aspec-cmd.get-text;
  $raw-action<o> = $aspec-icon.get-text;
  $raw-action<i> = $aspec-pic.get-text;
  $raw-action<l> = $aspec-log.get-state;
  $raw-action<w> = $aspec-wait.get-text.Int;
  $raw-action<p> = $aspec-path.get-text;

  my Str $original-id = $listbox.get-selection[0];
  my SessionManager::ActionData $action-data = $data-ids{$original-id};
  $action-data.init-action( :$raw-action, :id($original-id));
  $sts-ok = True;

#  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method actions-rename-id ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Modify Action'), :add-statusbar
  ) {
    my Entry $action-id .= new-entry;
    my Entry $aspec-title .= new-entry;
    my Entry $aspec-cmd .= new-entry;
    my Entry $aspec-path .= new-entry;
    my Entry $aspec-wait .= new-entry;
    my Switch $aspec-log .= new-switch;
    my Entry $aspec-icon .= new-entry;
    my Entry $aspec-pic .= new-entry;

    # Set placeholder texts when optional
    $aspec-path.set-placeholder-text('optional');
    $aspec-wait.set-placeholder-text('optional');
    $aspec-icon.set-placeholder-text('optional');
    $aspec-pic.set-placeholder-text('optional');
    
    my ListBox $listbox;
    my ScrolledWindow $scrolled-listbox;
    ( $listbox, $scrolled-listbox) = self.scrollable-list(
      :$dialog, :$action-id, :$aspec-title, :$aspec-cmd, :$aspec-path,
      :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic
    );

    .add-content( 'Current actions', $scrolled-listbox, :4columns);
    .add-content( 'Action id', $action-id, :4columns);

    .add-button(
      self, 'do-rename-act', 'Rename', :$dialog, :$action-id, :$listbox
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }

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
method do-rename-act (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id, ListBox :$listbox
) {
  my Str $id = $action-id.get-text;

  if !$id {
    $dialog.set-status('An action id may not be empty');
  }

  elsif $id ~~ any(|$data-ids.keys) {
    $dialog.set-status('This action id is already defined');
  }

  else {
    #TODO Rename references in sessions

    # Change the row in the listbox
    with my Label $l .= new-with-mnemonic($id) {
      .set-justify(GTK_JUSTIFY_LEFT);
      .set-halign(GTK_ALIGN_START);
    }
    # Change the id of the row in the list
#    $!original-row.set-child($l);

    # Set original
    $!original-id = $listbox.get-selection[0];
    my SessionManager::ActionData $adata = $data-ids{$!original-id}:delete;
    $data-ids{$id} = $adata;

    $dialog.set-status('Renamed everything successfully');
  }

  # Keep dialog open for other edits
}

#-------------------------------------------------------------------------------
method set-data(
  Label() $l, GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id,
  Entry :$aspec-title, Entry :$aspec-cmd, Entry :$aspec-path,
  Entry :$aspec-wait, Switch :$aspec-log, Entry :$aspec-icon,
  Entry :$aspec-pic
) {
  # Needed to rename content of row
#  $!original-row = $row;
#note "$?LINE";

#  my Label() $l = $row.get-child;
  my Str $id = $l.get-text;
#  $!original-id = $id;
  $action-id.set-text($id);

  my Hash $action-object = $data-ids{$id}.raw-action;
  $aspec-title.set-text($action-object<t>) if ?$action-object<t>;
  $aspec-cmd.set-text($action-object<c>) if ?$action-object<c>;
  $aspec-path.set-text($action-object<p>) if ?$action-object<p>;
  $aspec-wait.set-text($action-object<w>) if ?$action-object<w>;
  $aspec-log.set-state($action-object<l>.Bool) if ?$action-object<l>;
  $aspec-icon.set-text($action-object<o>) if ?$action-object<o>;
  $aspec-pic.set-text($action-object<i>) if ?$action-object<i>;
}
#`{{
}}

#-------------------------------------------------------------------------------
method actions-delete ( N-Object $parameter ) {
  note "$?LINE delete";
}

#-------------------------------------------------------------------------------
method scrollable-list ( Bool :$multi = False, *%options ) {

#note "$?LINE";
  my $object = self;
  my ListBox $list-lb .= new(
    :$object, :method<set-data>, :$multi, |%options
  );
  my ScrolledWindow $sw = $list-lb.set-list([|$data-ids.keys.sort]);

#`{{
  $list-lb.set-selection-mode(GTK_SELECTION_MULTIPLE) if $multi;
  for $data-ids.keys.sort -> $id {
    with my Label $l .= new-with-mnemonic($id) {
      .set-justify(GTK_JUSTIFY_LEFT);
      .set-halign(GTK_ALIGN_START);
    }
    $list-lb.append($l);
    $list-lb.register-signal( $object, $method, 'row-selected', |%options);
  }

  with my ScrolledWindow $sw .= new-scrolledwindow {
    .set-child($list-lb);
    .set-size-request( 850, 300);
  }

  $sw
}}
  ( $list-lb, $sw)
}

#-------------------------------------------------------------------------------
method get-ids ( --> Seq ) {
  $data-ids.keys.sort
}
