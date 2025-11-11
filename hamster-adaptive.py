#!/usr/bin/env python3
"""
Hamster Adaptive GUI - Ham Radio Manager
Adaptive interface that detects environment and optimizes accordingly:
- Touch screen support for Raspberry Pi
- Desktop optimization for full Linux systems
- Gaming console mode for handhelds
- Automatic input method detection (touch, keyboard, gamepad)
"""

import tkinter as tk
from tkinter import ttk, messagebox, simpledialog
import subprocess
import os
import sys
import threading
import time
import platform
import glob
import json
from pathlib import Path

class EnvironmentDetector:
    """Detect system environment and capabilities"""
    
    def __init__(self):
        self.environment = self.detect_environment()
        self.input_methods = self.detect_input_methods()
        self.screen_info = self.detect_screen_info()
        
    def detect_environment(self):
        """Detect the type of Linux environment"""
        env = {
            'type': 'unknown',
            'is_pi': False,
            'is_desktop': False,
            'is_console': False,
            'has_systemd': False,
            'desktop_environment': None
        }
        
        # Check if Raspberry Pi
        try:
            with open('/proc/cpuinfo', 'r') as f:
                if 'BCM' in f.read() or 'Raspberry' in f.read():
                    env['is_pi'] = True
                    env['type'] = 'raspberry_pi'
        except:
            pass
        
        # Check for desktop environment
        desktop_env = os.environ.get('DESKTOP_SESSION') or os.environ.get('XDG_CURRENT_DESKTOP')
        if desktop_env:
            env['is_desktop'] = True
            env['desktop_environment'] = desktop_env.lower()
            if env['type'] == 'unknown':
                env['type'] = 'desktop'
        
        # Check if running on gaming console (common characteristics)
        try:
            with open('/proc/device-tree/model', 'r') as f:
                model = f.read().lower()
                if any(console in model for console in ['rg', 'anbernic', 'powkiddy', 'retroid']):
                    env['is_console'] = True
                    env['type'] = 'gaming_console'
        except:
            pass
        
        # Check for systemd
        env['has_systemd'] = os.path.exists('/run/systemd/system')
        
        # If still unknown, default based on other factors
        if env['type'] == 'unknown':
            if env['is_desktop']:
                env['type'] = 'desktop'
            elif env['is_pi']:
                env['type'] = 'raspberry_pi'
            else:
                env['type'] = 'minimal_linux'
        
        return env
    
    def detect_input_methods(self):
        """Detect available input methods"""
        methods = {
            'keyboard': True,  # Assume always available
            'mouse': False,
            'touchscreen': False,
            'gamepad': False,
            'joystick_devices': []
        }
        
        # Check for touchscreen
        try:
            touch_devices = glob.glob('/dev/input/event*')
            for device in touch_devices:
                try:
                    # Check device capabilities
                    result = subprocess.run(['udevadm', 'info', '--query=property', f'--name={device}'], 
                                          capture_output=True, text=True)
                    if 'ID_INPUT_TOUCHSCREEN=1' in result.stdout:
                        methods['touchscreen'] = True
                        break
                except:
                    pass
        except:
            pass
        
        # Check for mouse
        methods['mouse'] = len(glob.glob('/dev/input/mouse*')) > 0
        
        # Check for gamepad/joystick
        joystick_devices = glob.glob('/dev/input/js*')
        methods['gamepad'] = len(joystick_devices) > 0
        methods['joystick_devices'] = joystick_devices
        
        return methods
    
    def detect_screen_info(self):
        """Detect screen resolution and DPI"""
        info = {
            'width': 1024,
            'height': 768,
            'dpi': 96,
            'is_small_screen': False,
            'is_touch_optimized': False
        }
        
        try:
            # Try to get screen info from xrandr
            result = subprocess.run(['xrandr'], capture_output=True, text=True)
            for line in result.stdout.split('\n'):
                if ' connected primary' in line or ' connected ' in line:
                    parts = line.split()
                    for part in parts:
                        if 'x' in part and '+' in part:
                            resolution = part.split('+')[0]
                            if 'x' in resolution:
                                width, height = map(int, resolution.split('x'))
                                info['width'] = width
                                info['height'] = height
                                break
                    break
        except:
            # Fallback to tkinter detection
            try:
                root = tk.Tk()
                info['width'] = root.winfo_screenwidth()
                info['height'] = root.winfo_screenheight()
                root.destroy()
            except:
                pass
        
        # Determine if small screen (typical for Pi touchscreen or console)
        info['is_small_screen'] = info['width'] <= 800 or info['height'] <= 480
        
        # Touch optimization heuristic
        info['is_touch_optimized'] = (self.input_methods['touchscreen'] and 
                                     info['is_small_screen']) or self.environment['is_pi']
        
        return info


class AdaptiveHamsterGUI:
    def __init__(self):
        self.detector = EnvironmentDetector()
        self.config = self.load_config()
        
        self.root = tk.Tk()
        self.setup_window()
        self.setup_styles()
        self.create_widgets()
        self.setup_input_handlers()
        self.check_system_status()
        
        # Show environment detection info
        self.show_environment_info()
        
    def load_config(self):
        """Load user configuration or create default"""
        config_file = os.path.expanduser('~/.config/hamster/config.json')
        default_config = {
            'station': {
                'callsign': 'N0CALL',
                'grid_square': 'FN42xx',
                'qth': 'Home Station',
                'operator': 'Ham Operator'
            },
            'ui': {
                'theme': 'auto',
                'font_size': 'auto',
                'touch_mode': 'auto'
            }
        }
        
        try:
            os.makedirs(os.path.dirname(config_file), exist_ok=True)
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    config = json.load(f)
                # Merge with defaults for missing keys
                for key in default_config:
                    if key not in config:
                        config[key] = default_config[key]
                return config
            else:
                with open(config_file, 'w') as f:
                    json.dump(default_config, f, indent=2)
                return default_config
        except:
            return default_config
    
    def save_config(self):
        """Save current configuration"""
        config_file = os.path.expanduser('~/.config/hamster/config.json')
        try:
            with open(config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            print(f"Failed to save config: {e}")
    
    def setup_window(self):
        """Setup window based on detected environment"""
        self.root.title("Hamster - Ham Radio Manager")
        
        env = self.detector.environment
        screen = self.detector.screen_info
        
        if env['type'] == 'gaming_console':
            # Gaming console optimization
            self.root.geometry("800x480")
            self.root.attributes('-fullscreen', True)
            self.window_mode = 'fullscreen_console'
            
        elif env['type'] == 'raspberry_pi' and screen['is_touch_optimized']:
            # Raspberry Pi touchscreen optimization
            if screen['is_small_screen']:
                self.root.geometry(f"{screen['width']}x{screen['height']}")
                self.root.attributes('-fullscreen', True)
            else:
                self.root.geometry("800x600")
                self.center_window()
            self.window_mode = 'touchscreen'
            
        elif env['type'] == 'desktop':
            # Full desktop optimization
            self.root.geometry("1000x700")
            self.center_window()
            self.root.minsize(800, 600)
            self.window_mode = 'desktop'
            
        else:
            # Minimal/unknown system
            self.root.geometry("800x600")
            self.center_window()
            self.window_mode = 'minimal'
        
        # Set window icon if available
        self.setup_window_icon()
        
        # Configure window based on capabilities
        self.root.configure(bg=self.get_theme_color('bg_primary'))
        
    def setup_window_icon(self):
        """Set window icon if available"""
        icon_paths = [
            os.path.join(os.path.dirname(__file__), 'docs', 'hamster-icon.png'),
            os.path.join(os.path.dirname(__file__), 'docs', 'icon.png'),
            '/usr/share/icons/hicolor/64x64/apps/hamster.png'
        ]
        
        for icon_path in icon_paths:
            if os.path.exists(icon_path):
                try:
                    self.root.iconphoto(True, tk.PhotoImage(file=icon_path))
                    break
                except:
                    pass
    
    def center_window(self):
        """Center window on screen"""
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() - self.root.winfo_width()) // 2
        y = (self.root.winfo_screenheight() - self.root.winfo_height()) // 2
        self.root.geometry(f"+{x}+{y}")
    
    def get_theme_color(self, element):
        """Get theme color based on environment"""
        # Dark theme for gaming consoles and small screens
        if self.window_mode in ['fullscreen_console', 'touchscreen']:
            colors = {
                'bg_primary': '#2c3e50',
                'bg_secondary': '#34495e',
                'fg_primary': '#ecf0f1',
                'fg_secondary': '#bdc3c7',
                'accent': '#3498db',
                'success': '#27ae60',
                'warning': '#f39c12',
                'error': '#e74c3c'
            }
        else:
            # Light theme for desktop
            colors = {
                'bg_primary': '#ffffff',
                'bg_secondary': '#f8f9fa',
                'fg_primary': '#212529',
                'fg_secondary': '#6c757d',
                'accent': '#007bff',
                'success': '#28a745',
                'warning': '#ffc107',
                'error': '#dc3545'
            }
        
        return colors.get(element, '#000000')
    
    def get_font_size(self, base_size):
        """Get font size based on screen and input method"""
        if self.detector.screen_info['is_touch_optimized']:
            return base_size + 4  # Larger fonts for touch
        elif self.detector.screen_info['is_small_screen']:
            return base_size + 2  # Slightly larger for small screens
        else:
            return base_size  # Normal size for desktop
    
    def setup_styles(self):
        """Setup adaptive styles"""
        style = ttk.Style()
        
        # Choose theme based on environment
        if self.window_mode in ['fullscreen_console', 'touchscreen']:
            try:
                style.theme_use('clam')
            except:
                pass
        else:
            try:
                style.theme_use('default')
            except:
                pass
        
        # Configure styles with adaptive sizing
        title_font_size = self.get_font_size(24)
        button_font_size = self.get_font_size(14)
        text_font_size = self.get_font_size(11)
        
        # Button padding based on input method
        if self.detector.input_methods['touchscreen']:
            button_padding = (30, 15)  # Larger padding for touch
        else:
            button_padding = (20, 10)  # Normal padding
        
        style.configure('Title.TLabel',
                       font=('Arial', title_font_size, 'bold'),
                       foreground=self.get_theme_color('fg_primary'),
                       background=self.get_theme_color('bg_primary'))
        
        style.configure('AdaptiveButton.TButton',
                       font=('Arial', button_font_size),
                       padding=button_padding)
        
        style.configure('Status.TLabel',
                       font=('Arial', text_font_size),
                       foreground=self.get_theme_color('success'),
                       background=self.get_theme_color('bg_secondary'))
    
    def setup_input_handlers(self):
        """Setup input handlers based on detected input methods"""
        # Always enable keyboard shortcuts
        self.setup_keyboard_shortcuts()
        
        # Enable touch gestures if touchscreen detected
        if self.detector.input_methods['touchscreen']:
            self.setup_touch_handlers()
        
        # Enable gamepad support if available
        if self.detector.input_methods['gamepad']:
            self.setup_gamepad_handlers()
        
        self.root.focus_set()
    
    def setup_keyboard_shortcuts(self):
        """Setup keyboard shortcuts"""
        shortcuts = {
            '<Key-1>': lambda e: self.launch_aprs(),
            '<Key-2>': lambda e: self.launch_qsstv(),
            '<Key-3>': lambda e: self.show_settings(),
            '<Key-4>': lambda e: self.check_dependencies(),
            '<Key-5>': lambda e: self.install_dependencies(),
            '<Return>': lambda e: self.launch_aprs(),
            '<space>': lambda e: self.launch_qsstv(),
            '<Escape>': lambda e: self.show_settings(),
            '<F1>': lambda e: self.show_help(),
            '<F5>': lambda e: self.refresh_status(),
            '<F11>': lambda e: self.toggle_fullscreen(),
            '<Control-q>': lambda e: self.root.quit()
        }
        
        for key, func in shortcuts.items():
            self.root.bind(key, func)
    
    def setup_touch_handlers(self):
        """Setup touch-specific handlers"""
        # Enable touch scrolling and gestures
        self.root.bind('<Button-1>', self.on_touch_start)
        self.root.bind('<B1-Motion>', self.on_touch_drag)
        self.root.bind('<ButtonRelease-1>', self.on_touch_end)
        
        # Double-tap for special actions
        self.root.bind('<Double-Button-1>', self.on_double_tap)
        
    def setup_gamepad_handlers(self):
        """Setup gamepad handlers"""
        # Note: This would require additional libraries like pygame for full gamepad support
        # For now, we'll use keyboard mapping that gamepads often provide
        pass
    
    def on_touch_start(self, event):
        """Handle touch start"""
        self.touch_start_x = event.x
        self.touch_start_y = event.y
    
    def on_touch_drag(self, event):
        """Handle touch drag"""
        pass  # Implement scrolling if needed
    
    def on_touch_end(self, event):
        """Handle touch end"""
        pass  # Implement gesture recognition if needed
    
    def on_double_tap(self, event):
        """Handle double tap"""
        # Quick action on double tap
        self.show_quick_menu()
    
    def toggle_fullscreen(self):
        """Toggle fullscreen mode"""
        current = self.root.attributes('-fullscreen')
        self.root.attributes('-fullscreen', not current)
    
    def create_widgets(self):
        """Create adaptive UI widgets"""
        # Main container with adaptive padding
        padding = 30 if self.detector.screen_info['is_touch_optimized'] else 20
        
        main_frame = tk.Frame(self.root, bg=self.get_theme_color('bg_primary'))
        main_frame.pack(fill=tk.BOTH, expand=True, padx=padding, pady=padding)
        
        # Create sections based on window mode
        if self.window_mode == 'desktop':
            self.create_desktop_layout(main_frame)
        elif self.window_mode in ['touchscreen', 'fullscreen_console']:
            self.create_touch_layout(main_frame)
        else:
            self.create_minimal_layout(main_frame)
    
    def create_desktop_layout(self, parent):
        """Create layout optimized for desktop"""
        # Use three-column layout for desktop
        
        # Left column - Status and info
        left_frame = tk.Frame(parent, bg=self.get_theme_color('bg_primary'))
        left_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=False, padx=(0, 10))
        
        # Middle column - Main buttons
        middle_frame = tk.Frame(parent, bg=self.get_theme_color('bg_primary'))
        middle_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10)
        
        # Right column - System info
        right_frame = tk.Frame(parent, bg=self.get_theme_color('bg_primary'))
        right_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=False, padx=(10, 0))
        
        self.create_title_section(middle_frame)
        self.create_main_buttons_desktop(middle_frame)
        self.create_status_section(left_frame)
        self.create_system_info_desktop(right_frame)
        self.create_environment_info(left_frame)
        
    def create_touch_layout(self, parent):
        """Create layout optimized for touch"""
        # Vertical layout with large touch targets
        
        self.create_title_section(parent)
        self.create_main_buttons_touch(parent)
        self.create_status_section_touch(parent)
        self.create_control_hints_touch(parent)
        
    def create_minimal_layout(self, parent):
        """Create minimal layout"""
        self.create_title_section(parent)
        self.create_main_buttons_minimal(parent)
        self.create_status_section(parent)
        
    def create_title_section(self, parent):
        """Create title section"""
        title_frame = tk.Frame(parent, bg=self.get_theme_color('bg_primary'))
        title_frame.pack(fill=tk.X, pady=(0, 20))
        
        # Adaptive title
        if self.detector.environment['is_pi']:
            title_text = "🔊 HAMSTER (Raspberry Pi)"
        elif self.detector.environment['is_console']:
            title_text = "🔊 HAMSTER (Console)"
        else:
            title_text = "🔊 HAMSTER"
        
        title_label = ttk.Label(title_frame, text=title_text, style='Title.TLabel')
        title_label.pack()
        
        subtitle_label = tk.Label(title_frame,
                                 text="Professional Amateur Radio Suite",
                                 font=('Arial', self.get_font_size(14)),
                                 fg=self.get_theme_color('fg_secondary'),
                                 bg=self.get_theme_color('bg_primary'))
        subtitle_label.pack()
    
    def create_main_buttons_desktop(self, parent):
        """Create main buttons for desktop layout"""
        button_frame = tk.Frame(parent, bg=self.get_theme_color('bg_primary'))
        button_frame.pack(fill=tk.BOTH, expand=True)
        
        # Large main buttons
        buttons = [
            ("📻 APRS Chatty X\nPacket Radio", self.launch_aprs, '#e74c3c'),
            ("📺 QSSTV\nSlow Scan TV", self.launch_qsstv, '#3498db'),
            ("🔧 Settings\nConfiguration", self.show_settings, '#f39c12'),
        ]
        
        for i, (text, command, color) in enumerate(buttons):
            btn = tk.Button(button_frame, text=text, command=command,
                          font=('Arial', self.get_font_size(16), 'bold'),
                          bg=color, fg='white',
                          width=20, height=4,
                          relief='raised', bd=3)
            btn.pack(fill=tk.X, pady=5)
        
        # Secondary buttons in grid
        secondary_frame = tk.Frame(button_frame, bg=self.get_theme_color('bg_primary'))
        secondary_frame.pack(fill=tk.X, pady=(20, 0))
        
        secondary_buttons = [
            ("📋 Check Deps", self.check_dependencies, '#9b59b6'),
            ("⬇️ Install", self.install_dependencies, '#27ae60'),
            ("ℹ️ System", self.show_system_info, '#34495e'),
            ("❓ Help", self.show_help, '#7f8c8d')
        ]
        
        for i, (text, command, color) in enumerate(secondary_buttons):
            btn = tk.Button(secondary_frame, text=text, command=command,
                          font=('Arial', self.get_font_size(12)),
                          bg=color, fg='white',
                          width=12, height=2)
            btn.grid(row=0, column=i, padx=2, pady=2)
            
        for i in range(4):
            secondary_frame.columnconfigure(i, weight=1)
    
    def create_main_buttons_touch(self, parent):
        """Create touch-optimized main buttons"""
        button_frame = tk.Frame(parent, bg=self.get_theme_color('bg_primary'))
        button_frame.pack(fill=tk.X, pady=(0, 20))
        
        # Extra large buttons for touch
        buttons = [
            ("📻 APRS Chatty X", self.launch_aprs, '#e74c3c'),
            ("📺 QSSTV", self.launch_qsstv, '#3498db'),
            ("🔧 Settings", self.show_settings, '#f39c12'),
        ]
        
        for text, command, color in buttons:
            btn = tk.Button(button_frame, text=text, command=command,
                          font=('Arial', self.get_font_size(20), 'bold'),
                          bg=color, fg='white',
                          height=3,
                          relief='raised', bd=4)
            btn.pack(fill=tk.X, pady=8)
            
            # Add touch feedback
            btn.bind('<Button-1>', lambda e, b=btn: self.touch_feedback(b, True))
            btn.bind('<ButtonRelease-1>', lambda e, b=btn: self.touch_feedback(b, False))
    
    def create_main_buttons_minimal(self, parent):
        """Create minimal buttons"""
        button_frame = tk.Frame(parent, bg=self.get_theme_color('bg_primary'))
        button_frame.pack(fill=tk.X, pady=(0, 20))
        
        buttons = [
            ("APRS", self.launch_aprs),
            ("QSSTV", self.launch_qsstv),
            ("Settings", self.show_settings),
            ("Help", self.show_help)
        ]
        
        for i, (text, command) in enumerate(buttons):
            btn = tk.Button(button_frame, text=text, command=command,
                          font=('Arial', self.get_font_size(12)))
            btn.grid(row=0, column=i, padx=2, pady=2, sticky='ew')
            
        for i in range(len(buttons)):
            button_frame.columnconfigure(i, weight=1)
    
    def touch_feedback(self, button, pressed):
        """Provide visual feedback for touch"""
        if pressed:
            button.config(relief='sunken', bd=2)
        else:
            button.config(relief='raised', bd=4)
    
    def create_status_section(self, parent):
        """Create status section"""
        status_frame = tk.LabelFrame(parent, text="System Status",
                                   bg=self.get_theme_color('bg_secondary'),
                                   fg=self.get_theme_color('fg_primary'),
                                   font=('Arial', self.get_font_size(12), 'bold'))
        status_frame.pack(fill=tk.X, pady=(0, 20))
        
        self.status_labels = {}
        status_items = [
            ('ssh', 'SSH'),
            ('bluetooth', 'Bluetooth'),
            ('network', 'Network'),
            ('direwolf', 'Direwolf'),
            ('qsstv', 'QSSTV')
        ]
        
        for i, (key, label) in enumerate(status_items):
            frame = tk.Frame(status_frame, bg=self.get_theme_color('bg_secondary'))
            frame.pack(fill=tk.X, padx=5, pady=2)
            
            tk.Label(frame, text=f"{label}:", 
                    bg=self.get_theme_color('bg_secondary'),
                    fg=self.get_theme_color('fg_primary'),
                    font=('Arial', self.get_font_size(10))).pack(side=tk.LEFT)
            
            self.status_labels[key] = tk.Label(frame, text="Checking...",
                                             bg=self.get_theme_color('bg_secondary'),
                                             fg=self.get_theme_color('warning'),
                                             font=('Arial', self.get_font_size(10), 'bold'))
            self.status_labels[key].pack(side=tk.RIGHT)
    
    def create_status_section_touch(self, parent):
        """Create touch-optimized status section"""
        status_frame = tk.Frame(parent, bg=self.get_theme_color('bg_secondary'))
        status_frame.pack(fill=tk.X, pady=(0, 20))
        
        # Horizontal status bar for touch screens
        self.status_text = tk.Label(status_frame, text="Checking system status...",
                                   bg=self.get_theme_color('bg_secondary'),
                                   fg=self.get_theme_color('fg_primary'),
                                   font=('Arial', self.get_font_size(12)))
        self.status_text.pack(fill=tk.X, padx=10, pady=5)
    
    def create_system_info_desktop(self, parent):
        """Create system info for desktop"""
        info_frame = tk.LabelFrame(parent, text="System Info",
                                 bg=self.get_theme_color('bg_secondary'),
                                 fg=self.get_theme_color('fg_primary'),
                                 font=('Arial', self.get_font_size(12), 'bold'))
        info_frame.pack(fill=tk.BOTH, expand=True)
        
        self.info_text_widget = tk.Text(info_frame,
                                       bg=self.get_theme_color('bg_secondary'),
                                       fg=self.get_theme_color('fg_primary'),
                                       font=('Monaco', self.get_font_size(9)),
                                       height=10, wrap=tk.WORD)
        self.info_text_widget.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
    def create_environment_info(self, parent):
        """Create environment detection info"""
        env_frame = tk.LabelFrame(parent, text="Environment",
                                bg=self.get_theme_color('bg_secondary'),
                                fg=self.get_theme_color('fg_primary'),
                                font=('Arial', self.get_font_size(12), 'bold'))
        env_frame.pack(fill=tk.X, pady=(20, 0))
        
        env = self.detector.environment
        input_methods = self.detector.input_methods
        
        env_text = f"Type: {env['type'].replace('_', ' ').title()}\n"
        if input_methods['touchscreen']:
            env_text += "Touch: Available\n"
        if input_methods['gamepad']:
            env_text += f"Gamepad: {len(input_methods['joystick_devices'])} detected\n"
        env_text += f"Mode: {self.window_mode}"
        
        tk.Label(env_frame, text=env_text,
                bg=self.get_theme_color('bg_secondary'),
                fg=self.get_theme_color('fg_secondary'),
                font=('Arial', self.get_font_size(9)),
                justify=tk.LEFT).pack(anchor='w', padx=5, pady=5)
    
    def create_control_hints_touch(self, parent):
        """Create control hints for touch"""
        hints_frame = tk.Frame(parent, bg=self.get_theme_color('bg_primary'))
        hints_frame.pack(fill=tk.X)
        
        if self.detector.input_methods['touchscreen']:
            hints_text = "👆 Touch buttons to launch • Double-tap for quick menu • F11 for fullscreen"
        else:
            hints_text = "⌨️ Use number keys for quick access • F1 for help • F11 for fullscreen"
            
        tk.Label(hints_frame, text=hints_text,
                bg=self.get_theme_color('bg_primary'),
                fg=self.get_theme_color('fg_secondary'),
                font=('Arial', self.get_font_size(9))).pack()
    
    def show_environment_info(self):
        """Show environment detection results on startup"""
        env = self.detector.environment
        screen = self.detector.screen_info
        inputs = self.detector.input_methods
        
        info_parts = []
        if env['is_pi']:
            info_parts.append("Raspberry Pi detected")
        if inputs['touchscreen']:
            info_parts.append("touchscreen available")
        if inputs['gamepad']:
            info_parts.append(f"{len(inputs['joystick_devices'])} gamepad(s)")
        
        if info_parts:
            info_text = f"Detected: {', '.join(info_parts)}"
        else:
            info_text = f"Running on {env['type'].replace('_', ' ')}"
            
        # Show briefly in status bar or as a temporary message
        if hasattr(self, 'status_text'):
            original_text = self.status_text.cget('text')
            self.status_text.config(text=info_text)
            self.root.after(3000, lambda: self.status_text.config(text=original_text))
    
    def check_system_status(self):
        """Check system status with adaptive display"""
        def update_status():
            status_info = {}
            
            try:
                # Check services
                for service in ['ssh', 'bluetooth']:
                    result = subprocess.run(['systemctl', 'is-active', service],
                                          capture_output=True, text=True)
                    status_info[service] = result.stdout.strip() == 'active'
                
                # Check network
                try:
                    result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
                    ip = result.stdout.strip().split()[0] if result.stdout.strip() else None
                    status_info['network'] = bool(ip)
                    status_info['ip'] = ip
                except:
                    status_info['network'] = False
                    status_info['ip'] = None
                
                # Check applications
                for app in ['direwolf', 'qsstv']:
                    result = subprocess.run(['which', app], capture_output=True)
                    status_info[app] = result.returncode == 0
                
                # Update UI
                self.update_status_display(status_info)
                
            except Exception as e:
                print(f"Error checking status: {e}")
        
        threading.Thread(target=update_status, daemon=True).start()
    
    def update_status_display(self, status_info):
        """Update status display based on layout"""
        if hasattr(self, 'status_labels'):
            # Desktop/minimal layout with individual labels
            for key, value in status_info.items():
                if key in self.status_labels:
                    if key == 'network' and status_info.get('ip'):
                        text = f"Connected ({status_info['ip'][:15]}...)"
                    else:
                        text = "Active" if value else "Inactive"
                    
                    color = self.get_theme_color('success') if value else self.get_theme_color('error')
                    self.status_labels[key].config(text=text, fg=color)
        
        if hasattr(self, 'status_text'):
            # Touch layout with single status line
            active_services = [k for k, v in status_info.items() if v and k not in ['ip']]
            status_text = f"Active: {', '.join(active_services)}"
            if status_info.get('ip'):
                status_text += f" | IP: {status_info['ip']}"
            self.status_text.config(text=status_text)
        
        # Update desktop system info if available
        if hasattr(self, 'info_text_widget'):
            self.update_system_info_text()
    
    def update_system_info_text(self):
        """Update system info text widget"""
        try:
            info = f"Environment: {self.detector.environment['type']}\n"
            info += f"Screen: {self.detector.screen_info['width']}x{self.detector.screen_info['height']}\n"
            info += f"Touch: {'Yes' if self.detector.input_methods['touchscreen'] else 'No'}\n"
            info += f"Gamepad: {'Yes' if self.detector.input_methods['gamepad'] else 'No'}\n"
            
            # Add system info
            try:
                uname = subprocess.run(['uname', '-r'], capture_output=True, text=True).stdout.strip()
                info += f"Kernel: {uname}\n"
            except:
                pass
            
            self.info_text_widget.delete(1.0, tk.END)
            self.info_text_widget.insert(1.0, info)
            
        except Exception as e:
            print(f"Error updating system info: {e}")
    
    def show_quick_menu(self):
        """Show quick access menu"""
        QuickMenuWindow(self.root, self)
    
    def launch_aprs(self):
        """Launch APRS Chatty X"""
        script_path = os.path.join(os.path.dirname(__file__), 'scripts', 'launch_aprs_chatty_x.sh')
        try:
            subprocess.Popen(['bash', script_path], start_new_session=True)
            self.show_message("APRS Chatty X", "Launching APRS Chatty X...")
        except Exception as e:
            self.show_error("Error", f"Failed to launch APRS Chatty X: {e}")
    
    def launch_qsstv(self):
        """Launch QSSTV"""
        script_path = os.path.join(os.path.dirname(__file__), 'scripts', 'launch_qsstv.sh')
        try:
            subprocess.Popen(['bash', script_path], start_new_session=True)
            self.show_message("QSSTV", "Launching QSSTV...")
        except Exception as e:
            self.show_error("Error", f"Failed to launch QSSTV: {e}")
    
    def show_settings(self):
        """Show adaptive settings window"""
        AdaptiveSettingsWindow(self.root, self)
    
    def check_dependencies(self):
        """Check dependencies"""
        self.run_script_in_terminal('check_dependencies.sh', 'Dependency Check')
    
    def install_dependencies(self):
        """Install dependencies with confirmation"""
        if self.show_confirm("Install Dependencies",
                           "Install ham radio applications and dependencies?\n\n"
                           "This requires sudo access and may take time."):
            self.run_script_in_terminal('install_dependencies.sh', 'Install Dependencies')
    
    def show_system_info(self):
        """Show system information window"""
        AdaptiveSystemInfoWindow(self.root, self)
    
    def show_help(self):
        """Show adaptive help"""
        help_text = self.get_adaptive_help_text()
        self.show_message("Help - Hamster Ham Radio Manager", help_text)
    
    def get_adaptive_help_text(self):
        """Get help text based on environment"""
        base_help = """🔊 HAMSTER - Ham Radio Manager

APPLICATIONS:
📻 APRS Chatty X - Packet radio messaging
📺 QSSTV - Slow-scan television

KEYBOARD SHORTCUTS:
1-3 - Quick app access
F1 - Help
F5 - Refresh
F11 - Toggle fullscreen
Ctrl+Q - Quit
"""
        
        if self.detector.input_methods['touchscreen']:
            base_help += "\nTOUCH CONTROLS:\n👆 Tap buttons to select\n✌️ Double-tap for quick menu\n"
        
        if self.detector.input_methods['gamepad']:
            base_help += "\nGAMEPAD CONTROLS:\n🎮 D-pad for navigation\n🅰 A button to select\n"
        
        return base_help
    
    def refresh_status(self):
        """Refresh system status"""
        self.check_system_status()
        self.show_message("Refresh", "System status refreshed!")
    
    def show_message(self, title, message):
        """Show message with adaptive styling"""
        messagebox.showinfo(title, message)
    
    def show_error(self, title, message):
        """Show error with adaptive styling"""
        messagebox.showerror(title, message)
    
    def show_confirm(self, title, message):
        """Show confirmation dialog"""
        return messagebox.askyesno(title, message)
    
    def run_script_in_terminal(self, script_name, title):
        """Run script in terminal"""
        script_path = os.path.join(os.path.dirname(__file__), 'scripts', script_name)
        try:
            terminals = ['x-terminal-emulator', 'gnome-terminal', 'xterm', 'konsole']
            for terminal in terminals:
                if subprocess.run(['which', terminal], capture_output=True).returncode == 0:
                    subprocess.Popen([terminal, '-e', f'bash {script_path}; read -p "Press Enter to close..."'])
                    break
            else:
                self.show_error("Error", "No terminal emulator found")
        except Exception as e:
            self.show_error("Error", f"Failed to run {script_name}: {e}")
    
    def run(self):
        """Start the adaptive GUI"""
        self.root.mainloop()


class QuickMenuWindow:
    """Quick access menu for touch devices"""
    
    def __init__(self, parent, main_app):
        self.main_app = main_app
        self.window = tk.Toplevel(parent)
        self.window.title("Quick Menu")
        self.window.geometry("300x200")
        self.window.configure(bg=main_app.get_theme_color('bg_primary'))
        self.window.grab_set()
        
        self.create_quick_menu()
        
    def create_quick_menu(self):
        """Create quick access menu"""
        buttons = [
            ("📻 APRS", self.main_app.launch_aprs),
            ("📺 QSSTV", self.main_app.launch_qsstv),
            ("🔧 Settings", self.main_app.show_settings),
            ("❌ Close", self.window.destroy)
        ]
        
        for text, command in buttons:
            btn = tk.Button(self.window, text=text, command=command,
                          font=('Arial', self.main_app.get_font_size(14)),
                          height=2)
            btn.pack(fill=tk.X, padx=20, pady=5)


class AdaptiveSettingsWindow:
    """Adaptive settings window"""
    
    def __init__(self, parent, main_app):
        self.main_app = main_app
        self.window = tk.Toplevel(parent)
        self.window.title("Hamster Settings")
        self.setup_settings_window()
        
    def setup_settings_window(self):
        """Setup settings window based on environment"""
        if self.main_app.window_mode == 'desktop':
            self.window.geometry("700x500")
        else:
            # Full screen for touch/console
            self.window.geometry(f"{self.main_app.detector.screen_info['width']}x{self.main_app.detector.screen_info['height']}")
        
        self.window.configure(bg=self.main_app.get_theme_color('bg_primary'))
        self.window.grab_set()
        
        self.create_settings_content()
    
    def create_settings_content(self):
        """Create settings content"""
        # Title
        title = tk.Label(self.window, text="System Settings",
                        font=('Arial', self.main_app.get_font_size(18), 'bold'),
                        bg=self.main_app.get_theme_color('bg_primary'),
                        fg=self.main_app.get_theme_color('fg_primary'))
        title.pack(pady=20)
        
        # Create notebook for settings tabs
        notebook = ttk.Notebook(self.window)
        notebook.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Add settings tabs
        self.create_network_tab(notebook)
        self.create_station_tab(notebook)
        self.create_system_tab(notebook)
        
        # Close button
        tk.Button(self.window, text="Close",
                 command=self.window.destroy,
                 font=('Arial', self.main_app.get_font_size(14)),
                 height=2).pack(pady=20)
    
    def create_network_tab(self, notebook):
        """Create network settings tab"""
        frame = tk.Frame(notebook, bg=self.main_app.get_theme_color('bg_secondary'))
        notebook.add(frame, text="Network")
        
        # Network controls
        controls = [
            ("Enable SSH", self.enable_ssh),
            ("Enable WiFi", self.enable_wifi),
            ("Configure Bluetooth", self.configure_bluetooth),
            ("Network Info", self.show_network_info)
        ]
        
        for text, command in controls:
            btn = tk.Button(frame, text=text, command=command,
                          font=('Arial', self.main_app.get_font_size(12)),
                          height=2)
            btn.pack(fill=tk.X, padx=20, pady=10)
    
    def create_station_tab(self, notebook):
        """Create ham station settings tab"""
        frame = tk.Frame(notebook, bg=self.main_app.get_theme_color('bg_secondary'))
        notebook.add(frame, text="Station")
        
        # Station settings form
        settings = [
            ("Callsign:", "callsign"),
            ("Grid Square:", "grid_square"),
            ("QTH:", "qth"),
            ("Operator:", "operator")
        ]
        
        self.station_entries = {}
        
        for label_text, key in settings:
            row_frame = tk.Frame(frame, bg=self.main_app.get_theme_color('bg_secondary'))
            row_frame.pack(fill=tk.X, padx=20, pady=10)
            
            tk.Label(row_frame, text=label_text,
                    bg=self.main_app.get_theme_color('bg_secondary'),
                    fg=self.main_app.get_theme_color('fg_primary'),
                    font=('Arial', self.main_app.get_font_size(12))).pack(side=tk.LEFT)
            
            entry = tk.Entry(row_frame, font=('Arial', self.main_app.get_font_size(12)))
            entry.pack(side=tk.RIGHT, fill=tk.X, expand=True, padx=(10, 0))
            entry.insert(0, self.main_app.config['station'].get(key, ''))
            self.station_entries[key] = entry
        
        # Save button
        tk.Button(frame, text="Save Station Settings",
                 command=self.save_station_settings,
                 font=('Arial', self.main_app.get_font_size(12)),
                 bg=self.main_app.get_theme_color('success'),
                 fg='white',
                 height=2).pack(fill=tk.X, padx=20, pady=20)
    
    def create_system_tab(self, notebook):
        """Create system settings tab"""
        frame = tk.Frame(notebook, bg=self.main_app.get_theme_color('bg_secondary'))
        notebook.add(frame, text="System")
        
        # System info display
        info_text = f"""Environment: {self.main_app.detector.environment['type']}
Screen: {self.main_app.detector.screen_info['width']}x{self.main_app.detector.screen_info['height']}
Touch: {'Available' if self.main_app.detector.input_methods['touchscreen'] else 'Not available'}
Gamepad: {'Available' if self.main_app.detector.input_methods['gamepad'] else 'Not available'}
Window Mode: {self.main_app.window_mode}"""
        
        tk.Label(frame, text=info_text,
                bg=self.main_app.get_theme_color('bg_secondary'),
                fg=self.main_app.get_theme_color('fg_primary'),
                font=('Arial', self.main_app.get_font_size(11)),
                justify=tk.LEFT).pack(anchor='w', padx=20, pady=20)
    
    def enable_ssh(self):
        """Enable SSH service"""
        try:
            subprocess.run(['sudo', 'systemctl', 'enable', 'ssh'], check=True)
            subprocess.run(['sudo', 'systemctl', 'start', 'ssh'], check=True)
            self.main_app.show_message("SSH", "SSH enabled successfully!")
        except Exception as e:
            self.main_app.show_error("Error", f"Failed to enable SSH: {e}")
    
    def enable_wifi(self):
        """Enable WiFi"""
        try:
            subprocess.run(['sudo', 'systemctl', 'enable', 'NetworkManager'], check=True)
            subprocess.run(['sudo', 'systemctl', 'start', 'NetworkManager'], check=True)
            self.main_app.show_message("WiFi", "WiFi enabled successfully!")
        except Exception as e:
            self.main_app.show_error("Error", f"Failed to enable WiFi: {e}")
    
    def configure_bluetooth(self):
        """Configure Bluetooth"""
        self.main_app.show_message("Bluetooth", "Use terminal: bluetoothctl for Bluetooth configuration")
    
    def show_network_info(self):
        """Show network information"""
        try:
            result = subprocess.run(['ip', 'addr'], capture_output=True, text=True)
            self.main_app.show_message("Network Info", result.stdout[:500] + "...")
        except:
            self.main_app.show_error("Error", "Failed to get network info")
    
    def save_station_settings(self):
        """Save station settings"""
        for key, entry in self.station_entries.items():
            self.main_app.config['station'][key] = entry.get()
        
        self.main_app.save_config()
        self.main_app.show_message("Settings", "Station settings saved!")


class AdaptiveSystemInfoWindow:
    """Adaptive system info window"""
    
    def __init__(self, parent, main_app):
        self.main_app = main_app
        self.window = tk.Toplevel(parent)
        self.window.title("System Information")
        
        if main_app.window_mode == 'desktop':
            self.window.geometry("600x500")
        else:
            self.window.geometry("400x300")
        
        self.window.configure(bg=main_app.get_theme_color('bg_primary'))
        self.window.grab_set()
        
        self.create_info_display()
    
    def create_info_display(self):
        """Create system info display"""
        # Scrollable text area
        text_frame = tk.Frame(self.window, bg=self.main_app.get_theme_color('bg_primary'))
        text_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        self.info_text = tk.Text(text_frame,
                               bg=self.main_app.get_theme_color('bg_secondary'),
                               fg=self.main_app.get_theme_color('fg_primary'),
                               font=('Monaco', self.main_app.get_font_size(10)),
                               wrap=tk.WORD)
        
        scrollbar = tk.Scrollbar(text_frame, command=self.info_text.yview)
        self.info_text.config(yscrollcommand=scrollbar.set)
        
        self.info_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.load_system_info()
        
        # Close button
        tk.Button(self.window, text="Close",
                 command=self.window.destroy,
                 font=('Arial', self.main_app.get_font_size(12)),
                 height=2).pack(pady=10)
    
    def load_system_info(self):
        """Load comprehensive system information"""
        info = "HAMSTER SYSTEM INFORMATION\n"
        info += "=" * 50 + "\n\n"
        
        # Environment detection
        env = self.main_app.detector.environment
        info += f"DETECTED ENVIRONMENT:\n"
        info += f"Type: {env['type']}\n"
        info += f"Raspberry Pi: {'Yes' if env['is_pi'] else 'No'}\n"
        info += f"Desktop Environment: {env['desktop_environment'] or 'None'}\n"
        info += f"Gaming Console: {'Yes' if env['is_console'] else 'No'}\n"
        info += f"Systemd: {'Yes' if env['has_systemd'] else 'No'}\n\n"
        
        # Input methods
        inputs = self.main_app.detector.input_methods
        info += f"INPUT METHODS:\n"
        info += f"Touchscreen: {'Yes' if inputs['touchscreen'] else 'No'}\n"
        info += f"Mouse: {'Yes' if inputs['mouse'] else 'No'}\n"
        info += f"Gamepad: {'Yes' if inputs['gamepad'] else 'No'}\n"
        if inputs['joystick_devices']:
            info += f"Joystick devices: {', '.join(inputs['joystick_devices'])}\n"
        info += "\n"
        
        # Screen info
        screen = self.main_app.detector.screen_info
        info += f"DISPLAY:\n"
        info += f"Resolution: {screen['width']}x{screen['height']}\n"
        info += f"Small screen: {'Yes' if screen['is_small_screen'] else 'No'}\n"
        info += f"Touch optimized: {'Yes' if screen['is_touch_optimized'] else 'No'}\n"
        info += f"Window mode: {self.main_app.window_mode}\n\n"
        
        try:
            # System info
            info += f"SYSTEM:\n"
            info += f"Kernel: {subprocess.run(['uname', '-r'], capture_output=True, text=True).stdout.strip()}\n"
            info += f"Architecture: {subprocess.run(['uname', '-m'], capture_output=True, text=True).stdout.strip()}\n"
            info += f"Python: {sys.version.split()[0]}\n"
            
            # Hardware info
            try:
                with open('/proc/meminfo', 'r') as f:
                    for line in f:
                        if 'MemTotal:' in line:
                            mem_kb = int(line.split()[1])
                            info += f"Memory: {round(mem_kb / 1024 / 1024, 1)} GB\n"
                            break
            except:
                info += "Memory: Unknown\n"
            
            # More detailed info...
            info += f"\n{subprocess.run(['df', '-h'], capture_output=True, text=True).stdout}"
            
        except Exception as e:
            info += f"Error loading system info: {e}\n"
        
        self.info_text.insert(tk.END, info)
        self.info_text.config(state=tk.DISABLED)


def main():
    """Main entry point for adaptive Hamster"""
    try:
        app = AdaptiveHamsterGUI()
        app.run()
    except KeyboardInterrupt:
        print("Hamster Adaptive GUI interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"Error starting Hamster Adaptive GUI: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()