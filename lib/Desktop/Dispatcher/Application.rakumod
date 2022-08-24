
use Getopt::Long;
use QA::Types;

use Gnome::Gtk3::CssProvider;
use Gnome::Gtk3::StyleContext;
use Gnome::Gtk3::StyleProvider;
use Gnome::Gtk3::Grid;
use Gnome::Gtk3::Application;
use Gnome::Gtk3::ApplicationWindow;
use Gnome::Gtk3::ScrolledWindow;
use Gnome::Gtk3::Button;
use Gnome::Gtk3::Image;
use Gnome::Gtk3::MenuBar;
use Gnome::Gtk3::Builder;
#use Gnome::Gtk3::Label;
use Gnome::Gtk3::Frame;

use Gnome::Gio::ApplicationCommandLine;
use Gnome::Gio::Enums;
#use Gnome::Gio::;

use Gnome::Gdk3::Pixbuf;
#use Gnome::Gdk3::Keysyms;
#use Gnome::Gdk3::Types;
use Gnome::Gdk3::Screen;

use Gnome::N::N-GObject;
#use Gnome::N::X;
#Gnome::N::debug(:on);

##`{{
#-------------------------------------------------------------------------------
#constant \Application            = Gnome::Gtk3::Application;
#constant \ApplicationWindow      = Gnome::Gtk3::ApplicationWindow;
constant \Image             = Gnome::Gtk3::Image;
constant \Grid              = Gnome::Gtk3::Grid;
constant \Button            = Gnome::Gtk3::Button;
constant \Frame             = Gnome::Gtk3::Frame;

#constant \MenuButton        = Gnome::Gtk3::MenuButton;
#constant \AccelGroup        = Gnome::Gtk3::AccelGroup;
constant \CssProvider       = Gnome::Gtk3::CssProvider;
constant \StyleContext      = Gnome::Gtk3::StyleContext;

constant \Pixbuf            = Gnome::Gdk3::Pixbuf;
constant \Screen            = Gnome::Gdk3::Screen;

#constant \SimpleAction      = Gnome::Gio::SimpleAction;
#constant \SimpleActionGroup = Gnome::Gio::SimpleActionGroup;
#constant \Menu              = Gnome::Gio::Menu;
#constant \MenuItem          = Gnome::Gio::MenuItem;
#constant \File              = Gnome::Gio::File;
#constant \FileIcon          = Gnome::Gio::FileIcon;

#constant \Closure           = Gnome::GObject::Closure;

constant \Variant           = Gnome::Glib::Variant;
constant \VariantType       = Gnome::Glib::VariantType;
#}}

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::Application:auth<github:MARTIMM>;
also is Gnome::Gtk3::Application;

has Gnome::Gtk3::ApplicationWindow $!app-window;
has Hash $!dispatch-config;

has Gnome::Gtk3::Grid $!groups-grid;

has Bool $!dispatch-testing;

#-------------------------------------------------------------------------------
# Initialize my application to be a Gnome::Gtk3::Application. The app will
# handle the commandline options of which a few are handled locally and others
# remotely.
submethod new ( |c ) {
  self.bless(
   :GtkApplication, :app-id($*application-id),
   :flags(G_APPLICATION_HANDLES_COMMAND_LINE),
   |c
  );
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!dispatch-testing = True;

  # Register all necessary signals
  self.register-signal( self, 'app-activate', 'activate');
  self.register-signal( self, 'local-options', 'handle-local-options');
  self.register-signal( self, 'remote-options', 'command-line');
  self.register-signal( self, 'shutdown', 'shutdown');
  self.register-signal( self, 'startup', 'startup');

  my Gnome::Glib::Error $e = self.register;
  die $e.message if $e.is-valid;
}

#-------------------------------------------------------------------------------
method local-options (
  N-GObject $no-vd --> Int
) {
  # By default, continue to proces remote options and/or activation of
  # primary instance
  my Int $exit-code = -1;

  CATCH { default { .message.note; $exit-code = 1; return $exit-code; } }

  # Local options which do not need a config file or primary instance
  my $o = get-options( |$*local-options, |$*remote-options);
  if $o<version> {
    say "Version of dispatcher is $*dispatcher-version";
    $exit-code = 0;
  }

  $exit-code
}

#-------------------------------------------------------------------------------
method remote-options (
  N-GObject $no-cl --> Int
) {
  # Assume success
  my Int $exit-code = 0;

  my Array $cmd-list = [];

  my Gnome::Gio::ApplicationCommandLine() $cl = $no-cl;
  my Array $args = $cl.get-arguments;
  my Capture $o = get-options-from( $args[1..*-1], |$*remote-options);
#note "o: $o.gist()";

  # These options are not local because 1) must stop a running primary instance
  # 2) uses the loaded/reloaded config 3) to activate a gui for clickable
  # and configurable actions.
  with $o {
    when .<stop> {
      self.quit;
    }

    when ?.<group> and ?.<actions> {
      my Hash $group-config = self.get-group-config(.<group>);
      if ?$group-config {
#note $group-config.gist;
        $cmd-list = self.get-actions( $group-config, .<group>, .<actions>);
        note self.dispatch($cmd-list);
      }

      else {
        $exit-code = 1;
      }
    }

    when ?.<group> {
      my Hash $group-config = self.get-group-config(.<group>);
      if ?$group-config {
#note $group-config.gist;
        $cmd-list = self.get-all-actions($group-config);
        note self.dispatch($cmd-list);
      }

      else {
        $exit-code = 1;
      }
    }

    default {
      self.activate unless $cl.get-is-remote;
    }
  }

  $cl.clear-object;

  $exit-code
}

#-------------------------------------------------------------------------------
method get-group-config ( Str:D $group --> Hash ) {

#note $!dispatch-config.gist;

  my Hash $group-cfg = $!dispatch-config<action-groups>;
  my Array $actions-group = [$group.split('/')];

  for @$actions-group -> $ap {
    if $group-cfg{$ap}:exists and $group-cfg{$ap} ~~ Hash {
      $group-cfg = $group-cfg{$ap};
    }

    else {
      note "group '$group', not found";
      $group-cfg = Hash;
      last;
    }
  }

  $group-cfg
}

#-------------------------------------------------------------------------------
method get-actions (
  Hash:D $group-config, Str $group, Str:D $actions --> Array
) {
  my Hash $group-cfg = $group-config<actions>;
  my Array $cmd-list = [];

  my Array $as = [$actions.split(',')];
  for @$as -> $a {
    if $group-cfg{$a}:exists {
      my $cmd = self.make-command( $a, $group-cfg{$a});
      if !$cmd {
        $cmd-list = [];
        last;
      }

      $cmd-list.push: $cmd;
    }

    else {
      note "action '$a', not found in group '$group'";
      $cmd-list = [];
      last;
    }
  }

  $cmd-list
}

#-------------------------------------------------------------------------------
method get-all-actions ( Hash:D $group-config --> Array ) {

  my Hash $group-cfg = $group-config<actions>;
  my Array $cmd-list = [];

  for $group-cfg.keys -> $a {
    my $cmd = self.make-command( $a, $group-cfg{$a});
    if !$cmd {
      $cmd-list = [];
      last;
    }

    $cmd-list.push: $cmd;
  }

  $cmd-list
}

#-------------------------------------------------------------------------------
method dispatch ( Array:D $cmd-list --> Bool ) {

  if !$cmd-list {
    note "Due to errors, actions are not executed";
    return False;
  }

  if $!dispatch-testing {
    note "\nTest mode is turned on; show commands only";
  }

  else {
    note "\nTest mode is turned off; next commands are executed";
  }

  for @$cmd-list -> $cmd {
    note "execute: '$cmd'";
    my Proc $proc = shell "$cmd &" unless $!dispatch-testing;
  }

  ?$cmd-list
}

#-------------------------------------------------------------------------------
method make-command ( Str $action, Hash $cmd-cfg --> Str ) {
#note "\naction: $cmd-cfg.gist()";

  # Can be a command or a large piece of text
  my Str $cmd = '';
  if $cmd-cfg<command> {
    $cmd = $cmd-cfg<command>;
    $cmd ~~ s:g/\s+/ /;
    $cmd ~~ s/\s+ $//;

    if $cmd ~~ m/^ [rm || mv || cp] \s / {
      note "command is inherently dangerous to execute from here - ignored";
      note "You still can shoot yourself in the foot, see https://www.tecmint.com/10-most-dangerous-commands-you-should-never-execute-on-linux/";
      $cmd = '';
    }
  }

  else {
    note "no command found to execute for this action '$action'";
  }

  $cmd
}

#-----------------------------------------------------------------------------
method !link-menu-action ( Str :$action, Str :$method is copy, Str :$state ) {

  $method //= $action;

  my Gnome::Gio::SimpleAction $menu-entry;
  if ?$state {
    $menu-entry .= new(
      :name($action),
      :parameter-type(Gnome::Glib::VariantType.new(:type-string<s>)),
      :state(Gnome::Glib::Variant.new(:parse("'$state'")))
    );
    $menu-entry.register-signal( self, $method, 'change-state');
  }

  else {
    $menu-entry .= new(
      :name($action),
#        :parameter-type(Gnome::Glib::VariantType.new(:type-string<s>))
    );
    $menu-entry.register-signal( self, $method, 'activate');
  }

  self.add-action($menu-entry);

  #cannot clear -> need to use it in handler!
  $menu-entry.clear-object;
}

#-------------------------------------------------------------------------------
method !set-groups-in-grid ( ) {
  my Int $group-count = 0;
  for $!dispatch-config<action-groups>.keys.sort -> $kg {
#note $!dispatch-config<action-groups>{$kg}.keys.gist;

    my Int $set-count = 0;
    my Grid $set-grid .= new;
    for $!dispatch-config<action-groups>{$kg}.keys.sort -> $ks {
      with my Button $sbutton .= new {
#        .set-always-show-image(True);
        .set-tooltip-text(
          $!dispatch-config<action-groups>{$kg}{$ks}<title> // $ks
        );

        my Str $icon = $!dispatch-config<action-groups>{$kg}{$ks}<icon> //
                       %?RESOURCES<config-icon.jpg>.Str;
#note "'$icon'";
        my Int() $icon-size = $!dispatch-config<theme><iconsize> // 64;
        my Pixbuf $pixbuf .= new(
          :file($icon), :width($icon-size),
          :height($icon-size), :preserve_aspect_ratio
        );

        my Gnome::Glib::Error $e = $pixbuf.last-error;
        if $e.is-valid {
          note "Image load error: ", $e.message;
        }

        else {
          .set-image(Image.new(:$pixbuf));
        }

        .register-signal(
          self, 'execute-actions', 'clicked',
          :action-config($!dispatch-config<action-groups>{$kg}{$ks})
        );
      }

      $set-grid.attach( $sbutton, $set-count++, 0, 1, 1);
    }

    with my Frame $frame .= new(:label("  $kg  ")) {
      .add($set-grid);
      .set-label-align( 0.05, 0.5);
    }

    $!groups-grid.attach( $frame, 0, $group-count++, 1, 1);
  }

#  $!groups-grid.show-all;
}

#-------------------------------------------------------------------------------
method !init-app-window ( N-GObject() $no-swin ) {

  my Str $desktop-theme =
    $!dispatch-config<theme><desktop-theme> // 'Adwaita:dark';
  my Str ( $name, $variant) = $desktop-theme.split(':');
  my StyleContext() $context .= new;
  my CssProvider() $css-provider .= new( :$name, :$variant);
  $context.add-provider-for-screen(
    Screen.new, $css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
  );
  $css-provider.clear-object;

  # set the class name of the grid managing groups
  $context = $!groups-grid.get-style-context;
  $context.add-class('groups-grid');

  with $!app-window .= new(:application(self)) {
    .add($no-swin);

    $context = .get-style-context;
    $context.add-class('dispatcher-window');
    $context.clear-object;

    my Str $wallpaper =
      $!dispatch-config<theme><wallpaper> // %?RESOURCES<steel-floor.jpg>.Str;
    my Str $menu-wallpaper =
      $!dispatch-config<theme><menu-wallpaper> // %?RESOURCES<brushed-light.jpg>.Str;
    my Str $groups-grid-color =
      $!dispatch-config<theme><groups-grid-color> // '255, 255, 255, 0';
    my Str $frame-tfg = $!dispatch-config<theme><frame-text-fg> // 'white';
    my Str $frame-tbg =
      $!dispatch-config<theme><frame-text-bg> // 'transparent';
    my Str $css = [~]
        '.dispatcher-window {', "\n",
        '  background: url("', $wallpaper, '") center / cover repeat;', "\n",
        "}\n\n",

        '.groups-grid {', "\n",
        '  background-color: rgba( ', $groups-grid-color, ");\n",
        "} \n\n",

        'frame > label {', "\n",
        "  color: $frame-tfg;\n",
        "  background-color: $frame-tbg;",
        "  font-weight: bold;\n",
        "  border-radius: 8px;\n",
        "}\n\n",

        'menubar {', "\n",
        '  background: url("', $menu-wallpaper, '") center / cover repeat;', "\n",
        "}\n";
#note "\ncss\n$css";

    $css-provider .= new;
    $css-provider.load-from-data($css);
    #$context .= new;
    $context.add-provider-for-screen(
      Screen.new, $css-provider, GTK_STYLE_PROVIDER_PRIORITY_USER
    );
    $css-provider.clear-object;


    my Int() $w = $!dispatch-config<theme><width> // 500;
    my Int() $h = $!dispatch-config<theme><height> // $w;
    .set-size-request( $w, $h);

    my Str $title = $!dispatch-config<theme><title> // 'Dispatcher';
    .set-title($title);

    my Str $icon = $!dispatch-config<theme><icon-file> //
                   %?RESOURCES<config-icon.jpg>.Str;
    my Pixbuf $win-icon .= new(
      :file($icon), :width(32), :height(32), :preserve_aspect_ratio
    );
    my Gnome::Glib::Error $e = $win-icon.last-error;
    if $e.is-valid {
      die "Error icon file: $e.message()";
    }

    else {
      .set-icon($win-icon);
    }

    .register-signal( self, 'exit-program', 'destroy');
    .show-all;
  }
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-- [callback handlers] --------------------------------------------------------
# Called after registration of the application
method startup ( ) {
  # Read the default configuration.
  my QA::Types $qa-types .= instance;
  $!dispatch-config = $qa-types.qa-load( 'dispatcher', :userdata);
  unless ?$!dispatch-config {
    note "dispatch configuration not found";
    $!dispatch-config = %();
  }

  $!dispatch-testing = $!dispatch-config<config><dispatch-testing> // True;
}

#-------------------------------------------------------------------------------
# Activation of the application takes place when processing remote options
# reach the default entry, or when setup options are processed.
# And when this process is also the primary instance, it's only called once
# because we don't need to create two gui's. This is completely automatically
# done.
method app-activate ( ) {

  # Load gui description of menu and set menubar
  my Gnome::Gtk3::Builder $builder .= new(
    :file(%?RESOURCES<dispatcher-menu.ui>.Str)
  );
  my Gnome::Gtk3::MenuBar $mbar .= new(:build-id<menubar>);
  self.set-menubar($mbar);

  # Activate menu entries
  self!link-menu-action(:action<new-group>);
  self!link-menu-action(:action<app-quit>);
#  self!link-menu-action(:action<show-index>);
  self!link-menu-action(:action<show-about>);
  self!link-menu-action(:action<test-dispatch>, :state<test-on>);

  # Add grid with groups in grid
  with $!groups-grid .= new {
    .set-border-width(5);
    self!set-groups-in-grid;
  }

  # Place grid in a scrollable window so we can move it up and down
  with my Gnome::Gtk3::ScrolledWindow $swin .= new {
    .add($!groups-grid);
  }


  # Set the theme and initialize application window and give this object (a
  # Gnome::Gtk3::Application) as its argument.
  self!init-app-window($swin);
}

#-------------------------------------------------------------------------------
# Handled after pressing the close button added by the desktop manager
method exit-program ( ) {
  self.quit;
}

#-------------------------------------------------------------------------------
method shutdown ( ) {
  # save changed config?
}

#-------------------------------------------------------------------------------
method execute-actions ( Hash :$action-config --> Bool ) {
  my Array $cmd-list = self.get-all-actions($action-config);
  self.dispatch($cmd-list);
}

#-------------------------------------------------------------------------------
#-- [menu entries] -------------------------------------------------------------
# Dispatch > New
method new-group ( N-GObject $n-parameter ) {
  my Gnome::Glib::Variant $v .= new(:native-object($n-parameter));
  note $v.print() if $v.is-valid;
  note "Select 'New' from 'File' menu";
}

#-------------------------------------------------------------------------------
# Dispatch > Quit
method app-quit ( N-GObject $n-parameter ) {
  note "Select 'Quit' from 'File' menu";
  my Gnome::Glib::Variant $v .= new(:native-object($n-parameter));
  note $v.print() if $v.is-valid;

  self.quit;
}

#-------------------------------------------------------------------------------
# Test Dispatch > Testing On/Off
method test-dispatch (
  Gnome::Glib::Variant() $value,
  Gnome::Gio::SimpleAction() :_native-object($test-mode-action),
) {
#note 'valid action: ', $test-mode-action.is-valid;
#note 'valid no: ', $no.gist;

#note "Select 'test' from 'configure' menu";
#note $test-mode-action.get-name;
  my Str $test-state = $value.print();
#note "Set to $test-state";
  $!dispatch-testing = $test-state eq 'test-on' ?? True !! False;

  $test-mode-action.set-state(
    Gnome::Glib::Variant.new(:parse($value.print))
  );
}

#`{{
#-------------------------------------------------------------------------------
# Help > Index
method show-index ( N-GObject $parameter ) {
#  note "Select 'Index' from 'Help' menu";
}
}}

#-------------------------------------------------------------------------------
# Help > About
method show-about ( N-GObject $parameter ) {
#  note "Select 'About' from 'Help' menu";
}
