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
use GnomeTools::Gtk::ListView;

use Gnome::Gtk4::TextBuffer:api<2>;
use Gnome::Gtk4::T-textiter:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Switch:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::TextView:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Widget:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Actions;

constant ListBox = GnomeTools::Gtk::ListBox;
constant ListView = GnomeTools::Gtk::ListView;
constant Dialog = GnomeTools::Gtk::Dialog;

constant Image = Gnome::Gtk4::Image;
constant Button = Gnome::Gtk4::Button;
constant Entry = Gnome::Gtk4::Entry;
constant Switch = Gnome::Gtk4::Switch;
constant Grid = Gnome::Gtk4::Grid;
constant Label = Gnome::Gtk4::Label;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant TextView = Gnome::Gtk4::TextView;
constant TextBuffer = Gnome::Gtk4::TextBuffer;
constant Widget = Gnome::Gtk4::Widget;
#constant TextIter = Gnome::Gtk4::TextIter;

#has SessionManager::Actions $!actions;

#-------------------------------------------------------------------------------
my SessionManager::Gui::Actions $instance;

has Hash $!data-ids;
has Str $!id-to-return-from-dialog = '';
has SessionManager::Actions $!actions;
has SessionManager::Sessions $!sessions;

has Dialog $!dialog;
has ListView $!actions-view;

has Entry $!action-id;
has Entry $!aspec-title;
has TextView $!aspec-cmd;
has Entry $!aspec-shell;
has Entry $!aspec-path;
has Entry $!aspec-wait;
has Switch $!aspec-log;
has Entry $!aspec-icon;
has Entry $!aspec-pic;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!data-ids = %();
  $!sessions .= new;
  $!actions .= new;
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> SessionManager::Gui::Actions ) {
  $instance //= self.bless;

  $instance
}

#`{{
#-------------------------------------------------------------------------------
method create ( N-Object $parameter ) {
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Create Action'), :add-statusbar, :!modal
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
#TODO add fields for variables and environment

    # Set placeholder texts when optional
    $aspec-path.set-placeholder-text('optional');
    $aspec-wait.set-placeholder-text('optional');
    $aspec-icon.set-placeholder-text('optional');
    $aspec-pic.set-placeholder-text('optional');

    my ListBox $listbox;
    my ScrolledWindow $scrolled-listbox;
    ( $listbox, $scrolled-listbox) = self.scrollable-list(
      :$dialog, :!modal, :$action-id, :$aspec-title, :$aspec-cmd,
      :$aspec-path, :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic,
      :$aspec-shell
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
}}

#--[menu entry create]----------------------------------------------------------
# Parameter is ignored but is needed here because native gnome routine calls it
# with an argument when called from a menu. Default value is set to the
# undefined N-Object so other methods can call it without an argument.
method create ( N-Object $parameter = N-Object --> Str ) {
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Create Action'), :add-statusbar, :!modal
  ) {
#TODO some fields should be multiline text
  $!action-id .= new-entry;
  $!aspec-title .= new-entry;
  $!aspec-cmd .= new-textview;
  $!aspec-shell .= new-entry;
  $!aspec-path .= new-entry;
  $!aspec-wait .= new-entry;
  $!aspec-log .= new-switch;
  $!aspec-icon .= new-entry;
  $!aspec-pic .= new-entry;
#TODO add fields for variables and environment

  # Set placeholder texts when optional
  $!aspec-path.set-placeholder-text('optional');
  $!aspec-wait.set-placeholder-text('optional');
  $!aspec-icon.set-placeholder-text('optional');
  $!aspec-pic.set-placeholder-text('optional');

  with $!actions-view .= new(:!multi-select) {
#    .set-events;
    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

    .set-selection-changed( self, 'set-input-fields');

    .append($!actions.get-action-ids.sort: {$^a.lc leg $^b.lc});
#    .append($!actions.get-action-idss[^2]);

    # Select the first one
    .set-selection(0);
  }
#`{{
    my ListView $listbox;
    my ScrolledWindow $scrolled-listbox;
    ( $listbox, $scrolled-listbox) = self.scrollable-list(
      :$dialog, :!modal, :$action-id, :$aspec-title, :$aspec-cmd,
      :$aspec-path, :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic,
      :$aspec-shell
    );
}}
#    .add-content( 'Current actions', $scrolled-listbox, :3columns);
    .add-content( 'Current actions', $!actions-view, :3columns);
    .add-content( 'Action id', $!action-id, $!aspec-title);
    .add-content( 'Command', $!aspec-cmd, :3columns);
    .add-content( 'Shell', $!aspec-shell, :3columns);
    .add-content( 'Path', $!aspec-path, :3columns);
    .add-content( 'Wait', $!aspec-wait, $!aspec-log);
    .add-content( 'Icon', $!aspec-icon, :3columns);
    .add-content( 'Picture', $!aspec-pic, :3columns);
#    .add-content( 'Environment', my Entry $aspec-env .= new-entry);
#    .add-content( 'Variables', my Entry $aspec-vars .= new-entry);
#    .add-content( '', my Entry $aspec- .= new-entry);

    .add-button( self, 'do-create-act', 'Create');
    .add-button( $dialog, 'destroy-dialog', 'Cancel');

    .set-size-request( 600, 800);
    .show-dialog;
  }

  $!id-to-return-from-dialog
}

#-------------------------------------------------------------------------------
method do-create-act (
  GnomeTools::Gtk::Dialog :$dialog, Entry :$action-id, Entry :$aspec-title,
  TextView :$aspec-cmd, Entry :$aspec-path, Entry :$aspec-wait,
  Switch :$aspec-log, Entry :$aspec-icon, Entry :$aspec-pic, Entry :$aspec-shell
) {
  my SessionManager::Actions $actions .= new;
  my Str $id = $action-id.get-text;
  my Bool $ok = False;

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
    $raw-action<o> = $config.set-picture($aspec-icon.get-text);
    $raw-action<i> = $config.set-picture($aspec-pic.get-text);
    $raw-action<l> = $aspec-log.get-state;
    $raw-action<w> = $aspec-wait.get-text.Int;
    $raw-action<p> = $aspec-path.get-text;
    $raw-action<sh> = $aspec-shell.get-text;

    $actions.add-action( $raw-action, :$id);
#    my SessionManager::ActionData $ad = $actions.get-action($id);
#    $ad.set-shell($aspec-shell.get-text);

#    $dialog.set-status("The action '$id' is succesfully created");
    $!id-to-return-from-dialog = $id;
    $ok = True;
  }

  $dialog.destroy-dialog if $ok;
}

#--[menu entry modify]----------------------------------------------------------
method modify ( N-Object $parameter = N-Object, Str :$target-id = '' --> Str ) {

  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Modify Action'), :add-statusbar, :!modal
  ) {
    my Label $action-id .= new-label;
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

    if ?$target-id {
      self.set-input-fields(
        :id($target-id), :$action-id, :$aspec-title, :$aspec-cmd, :$aspec-path,
        :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic, :$aspec-shell
      );
    }

    else {
      ( $listbox, $scrolled-listbox) = self.scrollable-list(
        :$dialog, :$action-id, :$aspec-title, :$aspec-cmd,
        :$aspec-path, :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic,
        :$aspec-shell
      );
      .add-content( 'Current actions', $scrolled-listbox, :3columns);
    }

    .add-content( 'Action id', $action-id, $aspec-title);
    .add-content( 'Command', $aspec-cmd, :3columns);
    .add-content( 'Shell', $aspec-shell, :3columns);
    .add-content( 'Path', $aspec-path, :3columns);
    .add-content( 'Wait', $aspec-wait, $aspec-log);
    .add-content( 'Icon', $aspec-icon, :3columns);
    .add-content( 'Picture', $aspec-pic, :3columns);
#    .add-content( 'Environment', my Entry $aspec-env .= new-entry);
#    .add-content( 'Variables', my Entry $aspec-vars .= new-entry);
#    .add-content( '', my Entry $aspec- .= new-entry);

    .add-button( self, 'do-modify-act', 'Modify', :$dialog, :$action-id,
      :$aspec-title, :$aspec-cmd, :$aspec-path, :$aspec-wait,
      :$aspec-log, :$aspec-icon, :$aspec-pic, :$aspec-shell
    );

    .add-button( $dialog, 'destroy-dialog', 'Cancel');
    .show-dialog;
  }

  $!id-to-return-from-dialog
}

#-------------------------------------------------------------------------------
method do-modify-act (
  GnomeTools::Gtk::Dialog :$dialog, Label :$action-id,
  Entry :$aspec-title, TextView :$aspec-cmd, Entry :$aspec-shell,
  Entry :$aspec-path, Entry :$aspec-wait, Switch :$aspec-log,
  Entry :$aspec-icon, Entry :$aspec-pic
) {
#  my Bool $ok = False;
  my SessionManager::Config $config .= instance;
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

  $raw-action<o> = $config.set-picture($aspec-icon.get-text);
  $raw-action<i> = $config.set-picture($aspec-pic.get-text);
  $raw-action<l> = $aspec-log.get-state;
  $raw-action<w> = $aspec-wait.get-text.Int;
  $raw-action<p> = $aspec-path.get-text;
  $raw-action<sh> = $aspec-shell.get-text;

#note "$?LINE $raw-action.gist()";
  my SessionManager::Actions $actions .= new;
  my Str $id = $action-id.get-text;
  $actions.modify-action( $id, $raw-action);

  $dialog.set-status("The action '$id' is succesfully modified");

  $!id-to-return-from-dialog = $id;
  $dialog.destroy-dialog;
}

#--[menu entry rename]----------------------------------------------------------
method rename ( N-Object $parameter ) {
  note "$?LINE ";
  with my GnomeTools::Gtk::Dialog $dialog .= new(
    :dialog-header('Rename Action'), :add-statusbar, :!modal
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
    .add-content( 'Action id', $action-id, $aspec-title);
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

    # Get the id and change the actions and action data
    my Str $id = $id-label.get-text;
    $actions.rename-action( $id, $new-id);

    # Change the use of actions in sessions
    $!sessions.rename-group-actions( $id, $new-id);

    # Change text in listbox row
    $id-label.set-text($new-id);

    $dialog.set-status('Renamed everything successfully');
  }
}

#-------------------------------------------------------------------------------
method set-data (
  Label() :$row-widget, Widget :$action-id,
  Entry :$aspec-title, TextView :$aspec-cmd, Entry :$aspec-path,
  Entry :$aspec-wait, Switch :$aspec-log, Entry :$aspec-icon,
  Entry :$aspec-pic, Entry :$aspec-shell
) {
  my Str $id = $row-widget.get-text;

  my Bool $aid-in-use = $!sessions.is-action-in-use($id);
  $action-id.set-css-classes($aid-in-use ?? "in-use" !! "not-in-use", 'abc');
  self.set-input-fields(
    :$id, :$action-id, :$aspec-title, :$aspec-cmd, :$aspec-path,
    :$aspec-wait, :$aspec-log, :$aspec-icon, :$aspec-pic, :$aspec-shell
  );
}

#-------------------------------------------------------------------------------
method set-input-fields ( UInt $pos, @selections,
  Str :id($old-id), Widget :$action-id,
  Entry :$aspec-title, TextView :$aspec-cmd, Entry :$aspec-path,
  Entry :$aspec-wait, Switch :$aspec-log, Entry :$aspec-icon,
  Entry :$aspec-pic, Entry :$aspec-shell
) {
#TODO show tooltip over fields with filled in variables
#  $!actions .= new;
  my $id = @selections[0];
  my Hash $action-object = $!actions.get-raw-action($id);

  $!action-id.set-text($id);

  with $!aspec-title { .set-text($action-object<t> // ''); }
  with $!aspec-cmd {
    my TextBuffer() $tb = .get-buffer;
    if ? my $s = $action-object<c> {
      $tb.set-text( $s, $s.chars);
    }

    else {
      $tb.set-text( '', 0);
    }
  }

  with $!aspec-path { .set-text($action-object<p> // ''); }
  with $!aspec-wait { .set-text($action-object<w> // ''); }
  with $!aspec-log { .set-state($action-object<l>.Bool); }
  with $!aspec-icon { .set-text($action-object<o> // ''); }
  with $!aspec-pic { .set-text($action-object<i> // ''); }
  with $!aspec-shell { .set-placeholder-text($action-object<sh>); }
}

#--[menu entry delete]----------------------------------------------------------
method delete ( N-Object $parameter ) {
  note "$?LINE delete";
}

#-------------------------------------------------------------------------------
method scrollable-list ( Bool :$multi = False, *%options ) {

  my SessionManager::Actions $actions .= new;
  my ListBox $list-lb .= new(
    :object(self), :method<set-data>, :$multi, |%options
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

  my Bool $name-inuse = self.check-action-inuse($name);
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