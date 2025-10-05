use v6.d;

use SessionManager::ActionData;
use SessionManager::Actions;
use SessionManager::Sessions;

use Digest::SHA256::Native;
use YAMLish;

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

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Actions;

has SessionManager::Actions $!actions;

#constant ConfigPath = '/Config/actions.yaml';

constant Entry = Gnome::Gtk4::Entry;
constant Switch = Gnome::Gtk4::Switch;
constant ListBox = GnomeTools::Gtk::ListBox;
#constant ListBoxRow = Gnome::Gtk4::ListBoxRow;
constant Label = Gnome::Gtk4::Label;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;

#-------------------------------------------------------------------------------
my SessionManager::Gui::Actions $instance;

has Hash $!data-ids;
#has Str $!original-id;
#has ListBoxRow $!original-row;
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
method actions-create ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Create Action'), :add-statusbar
  ) {
#TODO some fields should be multiline text
    my Entry $action-id .= new-entry;
    my Entry $aspec-title .= new-entry;
    my Entry $aspec-cmd .= new-entry;
    my Entry $aspec-shell .= new-entry;
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
      :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic, :$aspec-shell
    );

    .add-content( 'Current actions', $scrolled-listbox, :4columns);
    .add-content( 'Action id', $action-id, $aspec-title, :2columns);
#    .add-content( 'Action id', $action-id, :4columns);
#    .add-content( 'Title', $aspec-title, :4columns);
    .add-content( 'Command', $aspec-cmd, :4columns);
    .add-content( 'Shell', $aspec-shell, :4columns);
    .add-content( 'Path', $aspec-path, :4columns);
    .add-content( 'Wait', $aspec-wait, $aspec-log);
#    .add-content( 'Wait', $aspec-wait, :4columns);
#    .add-content( 'Logging', $aspec-log);
    .add-content( 'Icon', $aspec-icon, :4columns);
    .add-content( 'Picture', $aspec-pic, :4columns);
#    .add-content( 'Environment', my Entry $aspec-env .= new-entry);
#    .add-content( 'Variables', my Entry $aspec-vars .= new-entry);
#    .add-content( '', my Entry $aspec- .= new-entry);

    .add-button(
      self, 'do-create-act', 'Create', :$dialog, :$action-id,
      :$aspec-title, :$aspec-cmd, :$aspec-shell, :$aspec-path,
      :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic
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
  Entry :$aspec-icon, Entry :$aspec-pic, Entry :$aspec-shell
) {
  my Bool $sts-ok = False;
  my Str $id = $action-id.get-text;

  if !$id {
    $dialog.set-status('The action id may not be empty');
  }

  elsif $id ~~ any(|$!actions.get-action-ids.keys) {
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

    $!actions.add-action( $raw-action, :$id);
    my SessionManager::ActionData $ad = $!actions.get-action($id);
    $ad.set-shell($aspec-shell.get-text);

    $sts-ok = True;
    $dialog.set-status("The action '$id' is succesfully created");
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
    my Entry $aspec-shell .= new-entry;
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
      :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic, :$aspec-shell
    );

    .add-content( 'Current actions', $scrolled-listbox, :4columns);
    .add-content( 'Action id', $action-id, $aspec-title, :2columns);
#    .add-content( 'Action id', $action-id, :4columns);
#    .add-content( 'Title', $aspec-title, :4columns);
    .add-content( 'Command', $aspec-cmd, :4columns);
    .add-content( 'Shell', $aspec-shell, :4columns);
    .add-content( 'Path', $aspec-path, :4columns);
    .add-content( 'Wait', $aspec-wait, $aspec-log);
#    .add-content( 'Wait', $aspec-wait, :4columns);
#    .add-content( 'Logging', $aspec-log);
    .add-content( 'Icon', $aspec-icon, :4columns);
    .add-content( 'Picture', $aspec-pic, :4columns);
#    .add-content( 'Environment', my Entry $aspec-env .= new-entry);
#    .add-content( 'Variables', my Entry $aspec-vars .= new-entry);
#    .add-content( '', my Entry $aspec- .= new-entry);

    .add-button( self, 'do-modify-act', 'Modify', :$dialog, :$listbox,
      :$aspec-title, :$aspec-cmd, :$aspec-path, :$aspec-wait,
      :$aspec-log, :$aspec-icon, :$aspec-pic, :$aspec-shell
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
  Entry :$aspec-title, Entry :$aspec-cmd, Entry :$aspec-shell,
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

  my Str $id = $listbox.get-selection[0];
  $!actions.modify-action( $id, $raw-action);
  my SessionManager::ActionData $ad = $!actions.get-action($id);
  $ad.set-shell($aspec-shell.get-text);

  $dialog.set-status("The action '$id' is succesfully modified");
  $sts-ok = True;

#  $dialog.destroy-dialog if $sts-ok;
}

#-------------------------------------------------------------------------------
method actions-rename-id ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Rename Action'), :add-statusbar
  ) {
    my Entry $action-id .= new-entry;
    my Entry $aspec-title .= new-entry;
    my Entry $aspec-cmd .= new-entry;
    my Entry $aspec-shell .= new-entry;
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
      :$dialog, :$action-id,
#      :$aspec-title, :$aspec-cmd, :$aspec-path,
#      :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic, :$aspec-shell
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
  my Str $new-id = $action-id.get-text;

  if !$new-id {
    $dialog.set-status('An action id may not be empty');
  }

  elsif $new-id ~~ any(|$!actions.get-action-ids) {
    $dialog.set-status('This action id is already defined');
  }

  else {
    #TODO Rename references in sessions

    # Change the row in the listbox
    with my Label $l .= new-with-mnemonic($new-id) {
      .set-justify(GTK_JUSTIFY_LEFT);
      .set-halign(GTK_ALIGN_START);
    }
    # Change the id of the row in the list
#    $!original-row.set-child($l);

    # Set original, listbox is not in multi select so always one selection
    my $original-id = $listbox.get-selection[0];
    $!actions.rename-action( $original-id, $new-id);

    my SessionManager::Sessions $sessions .= new;
    $sessions.rename-group-actions( $original-id, $new-id);

    $dialog.set-status('Renamed everything successfully');
  }

  # Keep dialog open for other edits
}

#-------------------------------------------------------------------------------
method set-data(
  Label() :$row-widget, GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id,
  Entry :$aspec-title, Entry :$aspec-cmd, Entry :$aspec-path,
  Entry :$aspec-wait, Switch :$aspec-log, Entry :$aspec-icon,
  Entry :$aspec-pic, Entry :$aspec-shell
) {
  # Needed to rename content of row
#  $!original-row = $row;
#note "$?LINE";

#  my Label() $row-widget = $row.get-child;
  my Str $id = $row-widget.get-text;
  $action-id.set-text($id);

  my Hash $action-object = $!actions.get-raw-action($id);
  $aspec-title.set-text($action-object<t>)
    if ?$action-object<t> and ?$aspec-title;
  $aspec-cmd.set-text($action-object<c>)
    if ?$action-object<c> and ?$aspec-cmd;
  $aspec-path.set-text($action-object<p>)
    if ?$action-object<p> and ?$aspec-path;
  $aspec-wait.set-text($action-object<w>)
    if ?$action-object<w> and ?$aspec-wait;
  $aspec-log.set-state($action-object<l>.Bool)
    if ?$action-object<l> and ?$aspec-log;
  $aspec-icon.set-text($action-object<o>)
    if ?$action-object<o> and ?$aspec-icon;
  $aspec-pic.set-text($action-object<i>)
    if ?$action-object<i> and ?$aspec-pic;

  if ?$aspec-shell {
    my SessionManager::ActionData $ad = $!actions.get-action($id);
    $aspec-shell.set-placeholder-text($ad.get-shell);
  }
}

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
  my ScrolledWindow $sw = $list-lb.set-list([$!actions.get-action-ids.sort]);

#`{{
  $list-lb.set-selection-mode(GTK_SELECTION_MULTIPLE) if $multi;
  for $!data-ids.keys.sort -> $id {
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
