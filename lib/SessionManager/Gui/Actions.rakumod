use v6.d;
use NativeCall;

use SessionManager::ActionData;
use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Config;

use Digest::SHA256::Native;
use YAMLish;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListBox;

use Gnome::Gtk4::TextBuffer:api<2>;
use Gnome::Gtk4::T-textiter:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Switch:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::TextView:api<2>;
use Gnome::Gtk4::T-enums:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Actions;

constant ListBox = GnomeTools::Gtk::ListBox;

constant Entry = Gnome::Gtk4::Entry;
constant Switch = Gnome::Gtk4::Switch;
constant Label = Gnome::Gtk4::Label;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant TextView = Gnome::Gtk4::TextView;
constant TextBuffer = Gnome::Gtk4::TextBuffer;
#constant TextIter = Gnome::Gtk4::TextIter;

#has SessionManager::Actions $!actions;

#-------------------------------------------------------------------------------
my SessionManager::Gui::Actions $instance;

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
method create ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Create Action'), :add-statusbar
  ) {
#TODO some fields should be multiline text
    my Entry $action-id .= new-entry;
    my Entry $aspec-title .= new-entry;
    my TextView $aspec-cmd .= new-textview;
    my Entry $aspec-shell .= new-entry;
    my Entry $aspec-path .= new-entry;
    my Entry $aspec-wait .= new-entry;
    my Switch $aspec-log .= new-switch;
    my Entry $aspec-icon .= new-entry;
    my Entry $aspec-pic .= new-entry;
#TODO add fields for variables and environment

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

    .add-content( 'Current actions', $scrolled-listbox, :3columns);
    .add-content( 'Action id', [1, $action-id, 2, $aspec-title]);
    .add-content( 'Command', $aspec-cmd, :3columns);
    .add-content( 'Shell', $aspec-shell, :3columns);
    .add-content( 'Path', $aspec-path, :3columns);
    .add-content( 'Wait', $aspec-wait, $aspec-log);
    .add-content( 'Icon', $aspec-icon, :3columns);
    .add-content( 'Picture', $aspec-pic, :3columns);
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
}

#-------------------------------------------------------------------------------
method do-create-act (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id, Entry :$aspec-title,
  TextView :$aspec-cmd, Entry :$aspec-path, Entry :$aspec-wait,
  Switch :$aspec-log, Entry :$aspec-icon, Entry :$aspec-pic, Entry :$aspec-shell
) {
  my SessionManager::Actions $actions .= new;
  my Str $id = $action-id.get-text;

  if !$id {
    $dialog.set-status('The action id may not be empty');
  }

  elsif $id ~~ any(|$actions.get-action-ids.keys) {
    $dialog.set-status('This action id is already defined');
  }

  else {
    my SessionManager::Config $config .= instance;
    my Hash $raw-action = %();
    $raw-action<t> = $aspec-title.get-text;
#`{{
    my TextBuffer() $tb = $aspec-cmd.get-buffer;
    my N-TextIter() $t0 = $tb.get-start-iter;
    my N-TextIter() $te = $tb.get-end-iter;
    $raw-action<c> = $tb.get-text( $t0, $te, False);
}}
    $raw-action<c> = self.get-text($aspec-cmd);
    $raw-action<o> = $config.set-picture( $aspec-icon.get-text, :is-overlay);
    $raw-action<i> = $config.set-picture($aspec-pic.get-text);
    $raw-action<l> = $aspec-log.get-state;
    $raw-action<w> = $aspec-wait.get-text.Int;
    $raw-action<p> = $aspec-path.get-text;
    $raw-action<sh> = $aspec-shell.get-text;

    $actions.add-action( $raw-action, :$id);
#    my SessionManager::ActionData $ad = $actions.get-action($id);
#    $ad.set-shell($aspec-shell.get-text);

    $dialog.set-status("The action '$id' is succesfully created");
  }
}

#-------------------------------------------------------------------------------
method modify ( N-Object $parameter ) {

  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Modify Action'), :add-statusbar
  ) {
    my Entry $action-id .= new-entry;
    my Entry $aspec-title .= new-entry;
    my TextView $aspec-cmd .= new-textview;
    my Entry $aspec-shell .= new-entry;
    my Entry $aspec-path .= new-entry;
    my Entry $aspec-wait .= new-entry;
    my Switch $aspec-log .= new-switch;
    my Entry $aspec-icon .= new-entry;
    my Entry $aspec-pic .= new-entry;

    # Set pl$aspec-cmdceholder texts when optional
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

    .add-content( 'Current actions', $scrolled-listbox, :3columns);
    .add-content( 'Action id', [ 1, $action-id, 2, $aspec-title]);
    .add-content( 'Command', $aspec-cmd, :3columns);
    .add-content( 'Shell', $aspec-shell, :3columns);
    .add-content( 'Path', $aspec-path, :3columns);
    .add-content( 'Wait', [ 2, $aspec-wait, 1, $aspec-log]);
    .add-content( 'Icon', $aspec-icon, :3columns);
    .add-content( 'Picture', $aspec-pic, :3columns);
#    .add-content( 'Environment', my Entry $aspec-env .= new-entry);
#    .add-content( 'Variables', my Entry $aspec-vars .= new-entry);
#    .add-content( '', my Entry $aspec- .= new-entry);

    .add-button( self, 'do-modify-act', 'Modify', :$dialog, :$listbox,
      :$aspec-title, :$aspec-cmd, :$aspec-path, :$aspec-wait,
      :$aspec-log, :$aspec-icon, :$aspec-pic, :$aspec-shell
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');
    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-modify-act (
  GnomeTools::Gtk::Dialog :$dialog, ListBox :$listbox,
  Entry :$aspec-title, TextView :$aspec-cmd, Entry :$aspec-shell,
  Entry :$aspec-path, Entry :$aspec-wait, Switch :$aspec-log,
  Entry :$aspec-icon, Entry :$aspec-pic
) {
  my Hash $raw-action = %();
  $raw-action<t> = $aspec-title.get-text;
#`{{
  my TextBuffer() $tb = $aspec-cmd.get-buffer;
  my N-TextIter $t0 .= new;
  my N-TextIter $te .= new;
  $tb.get-bounds( $t0, $te);
  $raw-action<c> = $tb.get-text( $t0, $te, False);
}}
  $raw-action<c> = self.get-text($aspec-cmd);

  $raw-action<o> = $aspec-icon.get-text;
  $raw-action<i> = $aspec-pic.get-text;
  $raw-action<l> = $aspec-log.get-state;
  $raw-action<w> = $aspec-wait.get-text.Int;
  $raw-action<p> = $aspec-path.get-text;
  $raw-action<sh> = $aspec-shell.get-text;

  my SessionManager::Actions $actions .= new;
  my Str $id = $listbox.get-selection[0];
  $actions.modify-action( $id, $raw-action);

  $dialog.set-status("The action '$id' is succesfully modified");
}

#-------------------------------------------------------------------------------
method rename-id ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Rename Action'), :add-statusbar
  ) {
    my Entry $action-id .= new-entry;
    my Entry $aspec-title .= new-entry;
    my TextView $aspec-cmd .= new-textview;
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

    .add-content( 'Current actions', $scrolled-listbox, :3columns);
    .add-content( 'Action id', [ 1, $action-id, 2, $aspec-title]);
    .add-content( 'Command', $aspec-cmd, :3columns);
    .add-content( 'Shell', $aspec-shell, :3columns);
    .add-content( 'Path', $aspec-path, :3columns);
    .add-content( 'Wait', $aspec-wait, $aspec-log);
    .add-content( 'Icon', $aspec-icon, :3columns);
    .add-content( 'Picture', $aspec-pic, :3columns);

    .add-button(
      self, 'do-rename-act', 'Rename', :$dialog, :$action-id, :$listbox
    );

    .add-button( $dialog, 'destroy-dialog', 'Done');

    .show-dialog;
  }
}

#-------------------------------------------------------------------------------
method do-rename-act (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id, ListBox :$listbox
) {
  my SessionManager::Actions $actions .= new;
  my Str $new-id = $action-id.get-text;

  if !$new-id {
    $dialog.set-status('An action id may not be empty');
  }

  elsif $new-id ~~ any(|$actions.get-action-ids) {
    $dialog.set-status('This action id is already defined');
  }

  else {
    # Change the row in the listbox
    #with my Label $l .= new-with-mnemonic($new-id) {
    #  .set-justify(GTK_JUSTIFY_LEFT);
    #  .set-halign(GTK_ALIGN_START);
    #}

    # Get selected id, listbox is not in multi select so always one selection
    my Array $widgets = $listbox.get-selection(:get-widgets);
    my Label() $id-label = $widgets[0];

    # Get the id and change is actions and action data
    my Str $id = $id-label.get-text;
    $actions.rename-action( $id, $new-id);

    # Change the use of actions in sessions
    my SessionManager::Sessions $sessions .= new;
    $sessions.rename-group-actions( $id, $new-id);

    # Change text in listbox row
    $id-label.set-text($new-id);

    $dialog.set-status('Renamed everything successfully');
  }
}

#-------------------------------------------------------------------------------
method set-data(
  Label() :$row-widget, GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id,
  Entry :$aspec-title, TextView :$aspec-cmd, Entry :$aspec-path,
  Entry :$aspec-wait, Switch :$aspec-log, Entry :$aspec-icon,
  Entry :$aspec-pic, Entry :$aspec-shell
) {
  my SessionManager::Actions $actions .= new;
  my Str $id = $row-widget.get-text;
  $action-id.set-text($id);

  my SessionManager::Sessions $sessions .= new;
  my Bool $aid-in-use = $sessions.is-action-in-use($id);
  $action-id.set-css-classes($aid-in-use ?? "in-use" !! "not-in-use", 'abc');

#TODO show tooltip over fields with filled in variables

  my Hash $action-object = $actions.get-raw-action($id);
  with $aspec-title { .set-text($action-object<t> // ''); }
  with $aspec-cmd {
    my TextBuffer() $tb = .get-buffer;
    if ? my $s = $action-object<c> {
      $tb.set-text( $s, $s.chars);
    }

    else {
      $tb.set-text( '', 0);
    }
  }
note "\n$?LINE $aid-in-use, $action-object.gist()";
  with $aspec-path { .set-text($action-object<p> // ''); }
  with $aspec-wait { .set-text($action-object<w> // ''); }
  with $aspec-log { .set-state($action-object<l>.Bool); }
  with $aspec-icon { .set-text($action-object<o> // ''); }
  with $aspec-pic { .set-text($action-object<i> // ''); }
  with $aspec-shell { .set-placeholder-text($action-object<sh>); }
}

#-------------------------------------------------------------------------------
method delete ( N-Object $parameter ) {
  note "$?LINE delete";
}

#-------------------------------------------------------------------------------
method scrollable-list ( Bool :$multi = False, *%options ) {

  my SessionManager::Actions $actions .= new;
#note "$?LINE";
  my $object = self;
  my ListBox $list-lb .= new(
    :$object, :method<set-data>, :$multi, |%options
  );
  my ScrolledWindow $sw = $list-lb.set-list([$actions.get-action-ids.sort]);

  ( $list-lb, $sw)
}

#-------------------------------------------------------------------------------
method get-text ( TextView:D $textview --> Str ) {
  my TextBuffer() $tb = $textview.get-buffer;
  my N-TextIter $t0 .= new;
  my N-TextIter $te .= new;
  $tb.get-bounds( $t0, $te);

  $tb.get-text( $t0, $te, False)
}
