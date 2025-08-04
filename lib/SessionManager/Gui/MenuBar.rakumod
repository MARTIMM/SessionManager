
use v6.d;
use NativeCall;

use SessionManager::Gui::Actions;
use SessionManager::Gui::Variables;

use Gnome::Gio::Menu:api<2>;
use Gnome::Gio::MenuItem:api<2>;
use Gnome::Gio::SimpleAction:api<2>;

use Gnome::Gtk4::Button:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::MenuBar:auth<github:MARTIMM>;

has Gnome::Gio::Menu $.bar;
has $!application is required;
has $!main is required;

has Array $!menus;
has SessionManager::Gui::Actions $!action-edit;
has SessionManager::Gui::Variables $!variable-edit;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!application = $!main.application;
  $!action-edit .= instance;
  $!variable-edit .= instance;

  $!bar .= new-menu;
  $!menus = [
    self.make-menu( :menu-name<File>, :shortcut),
    self.make-menu( :menu-name<Actions>, :shortcut),
    self.make-menu( :menu-name<Variables>, :shortcut),
  ];
}

#-------------------------------------------------------------------------------
method make-menu (
  Str :$menu-name, Bool :$shortcut = False --> Gnome::Gio::Menu
) {
  my Gnome::Gio::Menu $menu .= new-menu;
  $!bar.append-submenu( $shortcut ?? "_$menu-name" !! "$menu-name", $menu);

#  my PuzzleTable::Config $config = $!main.config;

  with $menu-name {
    when 'File' {
      self.bind-action(
        $menu, $menu-name, self, 'Quit'
#        , :icon<application-exit>,
#        :tooltip('Quit application')
      );
    }

    when 'Actions' {
      self.bind-action(
        $menu, $menu-name, $!action-edit, 'Create Modify',
#        :icon<view-refresh>, :tooltip('Refresh sidebar')
      );
#      self.bind-action(
#        $menu, $menu-name, $!action-edit, 'Modify'
#        , :icon<application-exit>,
#        :tooltip('Quit application')
#      );
      self.bind-action(
        $menu, $menu-name, $!action-edit, 'Delete'
#        , :icon<application-exit>,
#        :tooltip('Quit application')
      );
    }

    when 'Variables' {
      self.bind-action(
        $menu, $menu-name, $!variable-edit, 'Add Modify',
#        :icon<view-refresh>, :tooltip('Refresh sidebar')
      );
#      self.bind-action(
#        $menu, $menu-name, $!variable-edit, 'Modify'
#        , :icon<application-exit>,
#        :tooltip('Quit application')
#      );
      self.bind-action(
        $menu, $menu-name, $!variable-edit, 'Delete'
#        , :icon<application-exit>,
#        :tooltip('Quit application')
      );
    }
  }
note "$?LINE $!bar.gist()";

  $menu
}

#-------------------------------------------------------------------------------
method bind-action (
  Gnome::Gio::Menu $menu, Str $menu-name, Mu $object, Str $entry-name,
  Str :$icon, Str :$path, Str :$tooltip, Bool :$shortcut = False
) {

  # Make a method and action name
  my Str $method = [~] $menu-name, ' ', $entry-name;
  $method .= lc;
  $method ~~ s:g/ \s+ /-/;

  my Str $action-name = 'app.' ~ $method;
note "$?LINE $menu-name, '$entry-name', $method, $action-name";

  # Make a menu entry
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem(
    $shortcut ?? "_$entry-name" !! $entry-name, $action-name
  );
  $menu.append-item($menu-item);

  # Use the method name
  my Gnome::Gio::SimpleAction $action .= new-simpleaction( $method, Pointer);
  $!application.add-action($action);
  $action.register-signal( $object, $method, 'activate');
#`{{
  if ?$icon {
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$icon, :$action-name
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $!main.toolbar.append($toolbar-button);
  }

  elsif ?$path {
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$path, :$action-name
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $!main.toolbar.append($toolbar-button);
  }
}}
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  say 'file quit';
  $!application.quit;
}












=finish
use PuzzleTable::Types;
use PuzzleTable::Config;
use PuzzleTable::Gui::Container;
use PuzzleTable::Gui::Category;
use PuzzleTable::Gui::Puzzle;
#use PuzzleTable::Gui::Sidebar;
use PuzzleTable::Gui::Settings;
use PuzzleTable::Gui::IconButton;
use PuzzleTable::Gui::Help;

#use Gnome::Glib::N-VariantType:api<2>;

use Gnome::Gio::Menu:api<2>;
use Gnome::Gio::MenuItem:api<2>;
use Gnome::Gio::SimpleAction:api<2>;

use Gnome::Gtk4::Button:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

#-------------------------------------------------------------------------------
unit class PuzzleTable::Gui::MenuBar:auth<github:MARTIMM>;

has Gnome::Gio::Menu $.bar;
has $!application is required;
has $!main is required;

has Array $!menus;
has PuzzleTable::Gui::Puzzle $!phandling;
has PuzzleTable::Gui::Category $!action-edit;
has PuzzleTable::Gui::Container $!cont;
has PuzzleTable::Gui::Settings $!set;
has PuzzleTable::Gui::Help $!help;

#-------------------------------------------------------------------------------
submethod BUILD ( :$!main ) {
  $!application = $!main.application;
  $!phandling .= new(:$!main);
  $!set .= new(:$!main);
  $!help .= new(:$!main);
  $!action-edit .= new(:$!main);
  $!cont .= new(:$!main);

  $!bar .= new-menu;
  $!menus = [
    self.make-menu(:menu-name<File>, :shortcut),
    self.make-menu(:menu-name<Container>),
    self.make-menu(:menu-name<Category>),
    self.make-menu(:menu-name<Puzzle>),
    self.make-menu(:menu-name<Settings>),
    self.make-menu(:menu-name<Help>),
  ];
}

#-------------------------------------------------------------------------------
method make-menu (
  Str :$menu-name, Bool :$shortcut = False --> Gnome::Gio::Menu
) {
  my Gnome::Gio::Menu $menu .= new-menu;
  $!bar.append-submenu( $shortcut ?? "_$menu-name" !! "$menu-name", $menu);

#  my PuzzleTable::Config $config = $!main.config;

  with $menu-name {
    when 'File' {
      self.bind-action(
        $menu, $menu-name, $!action-edit, 'Refresh Sidebar',
        :icon<view-refresh>, :tooltip('Refresh sidebar')
      );
      self.bind-action(
        $menu, $menu-name, self, 'Quit'
#        , :icon<application-exit>,
#        :tooltip('Quit application')
      );
    }

    when 'Container' {
      self.bind-action( $menu, $menu-name, $!cont, 'Add');
      self.bind-action( $menu, $menu-name, $!cont, 'Rename');
      self.bind-action( $menu, $menu-name, $!cont, 'Delete');
    }

    when 'Category' {
      self.bind-action(
        $menu, $menu-name, $!action-edit, 'Add',
        :path(DATA_DIR ~ 'images/add-cat.png'), :tooltip('Add a new category')
      );
      self.bind-action(
        $menu, $menu-name, $!action-edit, 'Rename',
        :path(DATA_DIR ~ 'images/ren-cat.png'), :tooltip('Rename a category')
      );
      self.bind-action( $menu, $menu-name, $!action-edit, 'Delete');
      self.bind-action( $menu, $menu-name, $!action-edit, 'Lock');
    }

    when 'Puzzle' {
      self.bind-action(
        $menu, $menu-name, $!phandling, 'Move',
        :path(DATA_DIR ~ 'images/move-64.png'), :tooltip('Move puzzles')
      );
      self.bind-action(
        $menu, $menu-name, $!phandling, 'Archive',
#        :path(DATA_DIR ~ 'images/archive-64.png'), :tooltip('Archive puzzles')
      );
    }

    when 'Settings' {
      self.bind-action( $menu, $menu-name, $!set, 'Set Password');
      self.bind-action(
        $menu, $menu-name, $!set, 'Unlock Categories',
        :shortcut
#        :icon<changes-allow>, :tooltip('Unlock locked categories')
      );
      self.bind-action(
        $menu, $menu-name, $!set, 'Lock Categories',
        :shortcut
      );
    }

    when 'Help' {
      self.bind-action( $menu, $menu-name, $!help, 'About',
        :icon<help-about>, :tooltip('About Info')
      );
      self.bind-action( $menu, $menu-name, $!help, 'Show Shortcuts Window');
    }
  }

  $menu
}

#-------------------------------------------------------------------------------
method bind-action (
  Gnome::Gio::Menu $menu, Str $menu-name, Mu $object, Str $entry-name,
  Str :$icon, Str :$path, Str :$tooltip, Bool :$shortcut = False
) {
  my PuzzleTable::Config $config .= instance;

  # Make a method and action name
  my Str $method = [~] $menu-name, ' ', $entry-name;
  $method .= lc;
  $method ~~ s:g/ \s+ /-/;

  my Str $action-name = 'app.' ~ $method;
#note "$?LINE $menu-name, '$entry-name', $method, $action-name";

  # Make a menu entry
  my Gnome::Gio::MenuItem $menu-item .= new-menuitem(
    $shortcut ?? "_$entry-name" !! $entry-name, $action-name
  );
  $menu.append-item($menu-item);

  # Use the method name
  my Gnome::Gio::SimpleAction $action .= new-simpleaction( $method, Pointer);
  $!application.add-action($action);
  $action.register-signal( $object, $method, 'activate');

  if ?$icon {
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$icon, :$action-name
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $!main.toolbar.append($toolbar-button);
  }

  elsif ?$path {
    my PuzzleTable::Gui::IconButton $toolbar-button .= new-button(
      :$path, :$action-name
    );

    $toolbar-button.set-tooltip-text($tooltip) if ?$tooltip;

    $!main.toolbar.append($toolbar-button);
  }
}
