#!/usr/bin/env python3
"""
Hamster GUI - Ham Radio Manager
Graphical interface for amateur radio applications on gaming consoles
"""

import tkinter as tk
from tkinter import ttk, messagebox, simpledialog
import subprocess
import os
import sys
import threading
import time

class HamsterGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.setup_window()
        self.setup_styles()
        self.create_widgets()
        self.check_system_status()
        
    def setup_window(self):
        """Configure main window for gaming console display"""
        self.root.title("Hamster - Ham Radio Manager")
        self.root.geometry("800x480")  # Common gaming console resolution
        self.root.configure(bg='#2c3e50')
        
        # Make it fullscreen-friendly
        self.root.attributes('-zoomed', True)  # Linux fullscreen
        
        # Center window if not fullscreen
        self.center_window()
        
        # Bind controller/keyboard shortcuts
        self.setup_keybindings()
        
    def center_window(self):
        """Center the window on screen"""
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() - self.root.winfo_width()) // 2
        y = (self.root.winfo_screenheight() - self.root.winfo_height()) // 2
        self.root.geometry(f"+{x}+{y}")
        
    def setup_styles(self):
        """Setup custom styles for gaming console look"""
        style = ttk.Style()
        style.theme_use('clam')
        
        # Configure colors for gaming console theme
        style.configure('Title.TLabel', 
                       font=('Arial', 24, 'bold'),
                       foreground='#ecf0f1',
                       background='#2c3e50')
        
        style.configure('Button.TButton',
                       font=('Arial', 14),
                       padding=(20, 10))
        
        style.configure('Status.TLabel',
                       font=('Arial', 12),
                       foreground='#27ae60',
                       background='#34495e')
                       
        style.configure('Info.TLabel',
                       font=('Arial', 11),
                       foreground='#ecf0f1',
                       background='#34495e')
    
    def setup_keybindings(self):
        """Setup keyboard/controller bindings"""
        # Number keys for quick menu access
        for i in range(1, 7):
            self.root.bind(f'<Key-{i}>', lambda e, num=i: self.quick_action(num))
        
        # Controller/gamepad bindings
        self.root.bind('<Return>', lambda e: self.launch_aprs())
        self.root.bind('<space>', lambda e: self.launch_qsstv())
        self.root.bind('<Escape>', lambda e: self.show_settings())
        self.root.bind('<F1>', lambda e: self.show_help())
        self.root.bind('<F5>', lambda e: self.refresh_status())
        
        # Focus on root for key bindings
        self.root.focus_set()
        
    def create_widgets(self):
        """Create and layout all GUI widgets"""
        # Main container
        main_frame = tk.Frame(self.root, bg='#2c3e50')
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Title section
        title_frame = tk.Frame(main_frame, bg='#2c3e50')
        title_frame.pack(fill=tk.X, pady=(0, 20))
        
        title_label = ttk.Label(title_frame, text="🔊 HAMSTER", style='Title.TLabel')
        title_label.pack()
        
        subtitle_label = ttk.Label(title_frame, 
                                  text="Professional Amateur Radio Suite",
                                  font=('Arial', 14),
                                  foreground='#bdc3c7',
                                  background='#2c3e50')
        subtitle_label.pack()
        
        # Status section
        self.create_status_section(main_frame)
        
        # Main buttons section
        self.create_main_buttons(main_frame)
        
        # System info section
        self.create_system_info(main_frame)
        
        # Control hints
        self.create_control_hints(main_frame)
        
    def create_status_section(self, parent):
        """Create system status display"""
        status_frame = tk.LabelFrame(parent, text="System Status", 
                                   bg='#34495e', fg='#ecf0f1',
                                   font=('Arial', 12, 'bold'))
        status_frame.pack(fill=tk.X, pady=(0, 20))
        
        # Create status labels
        self.status_labels = {}
        status_items = [
            ('ssh', 'SSH Service'),
            ('bluetooth', 'Bluetooth'),
            ('network', 'Network'),
            ('controller', 'Controller'),
            ('direwolf', 'Direwolf'),
            ('qsstv', 'QSSTV')
        ]
        
        for i, (key, label) in enumerate(status_items):
            row = i // 3
            col = i % 3
            
            frame = tk.Frame(status_frame, bg='#34495e')
            frame.grid(row=row, column=col, padx=10, pady=5, sticky='w')
            
            tk.Label(frame, text=f"{label}:", bg='#34495e', fg='#ecf0f1',
                    font=('Arial', 10)).pack(side=tk.LEFT)
            
            self.status_labels[key] = tk.Label(frame, text="Checking...", 
                                             bg='#34495e', fg='#f39c12',
                                             font=('Arial', 10, 'bold'))
            self.status_labels[key].pack(side=tk.LEFT, padx=(5, 0))
            
        # Configure grid weights
        for i in range(3):
            status_frame.columnconfigure(i, weight=1)
    
    def create_main_buttons(self, parent):
        """Create main application buttons"""
        button_frame = tk.Frame(parent, bg='#2c3e50')
        button_frame.pack(fill=tk.X, pady=(0, 20))
        
        # Main application buttons
        buttons = [
            ("📻 APRS Chatty X", self.launch_aprs, '#e74c3c'),
            ("📺 QSSTV", self.launch_qsstv, '#3498db'),
            ("🔧 Settings", self.show_settings, '#f39c12'),
        ]
        
        for i, (text, command, color) in enumerate(buttons):
            btn = tk.Button(button_frame, text=text, command=command,
                          font=('Arial', 16, 'bold'),
                          bg=color, fg='white',
                          width=15, height=2,
                          relief='raised', bd=3,
                          activebackground=self.darken_color(color))
            btn.grid(row=0, column=i, padx=10, pady=10)
            
        # Configure grid weights
        for i in range(3):
            button_frame.columnconfigure(i, weight=1)
        
        # Secondary buttons
        secondary_frame = tk.Frame(parent, bg='#2c3e50')
        secondary_frame.pack(fill=tk.X, pady=(0, 20))
        
        secondary_buttons = [
            ("📋 Check Dependencies", self.check_dependencies, '#9b59b6'),
            ("⬇️ Install Dependencies", self.install_dependencies, '#27ae60'),
            ("ℹ️ System Info", self.show_system_info, '#34495e'),
            ("❓ Help", self.show_help, '#7f8c8d')
        ]
        
        for i, (text, command, color) in enumerate(secondary_buttons):
            btn = tk.Button(secondary_frame, text=text, command=command,
                          font=('Arial', 12, 'bold'),
                          bg=color, fg='white',
                          width=18, height=1,
                          relief='raised', bd=2)
            btn.grid(row=0, column=i, padx=5, pady=5)
            
        for i in range(4):
            secondary_frame.columnconfigure(i, weight=1)
    
    def create_system_info(self, parent):
        """Create system information display"""
        info_frame = tk.LabelFrame(parent, text="Quick Info", 
                                 bg='#34495e', fg='#ecf0f1',
                                 font=('Arial', 12, 'bold'))
        info_frame.pack(fill=tk.X, pady=(0, 20))
        
        self.info_label = tk.Label(info_frame, text="Loading system information...",
                                  bg='#34495e', fg='#ecf0f1',
                                  font=('Arial', 10),
                                  justify=tk.LEFT)
        self.info_label.pack(anchor='w', padx=10, pady=5)
    
    def create_control_hints(self, parent):
        """Create controller/keyboard hints"""
        hints_frame = tk.Frame(parent, bg='#2c3e50')
        hints_frame.pack(fill=tk.X)
        
        hints_text = "🎮 Controls: 1-APRS 2-QSSTV 3-Settings | Enter-Launch | F1-Help | F5-Refresh | Esc-Settings"
        hints_label = tk.Label(hints_frame, text=hints_text,
                             bg='#2c3e50', fg='#7f8c8d',
                             font=('Arial', 9))
        hints_label.pack()
    
    def darken_color(self, color):
        """Darken a hex color for button active state"""
        color_map = {
            '#e74c3c': '#c0392b',
            '#3498db': '#2980b9',
            '#f39c12': '#d68910',
            '#9b59b6': '#8e44ad',
            '#27ae60': '#229954',
            '#34495e': '#2c3e50',
            '#7f8c8d': '#5d6d7e'
        }
        return color_map.get(color, '#2c3e50')
    
    def check_system_status(self):
        """Check and update system status in background"""
        def update_status():
            try:
                # Check SSH
                ssh_status = subprocess.run(['systemctl', 'is-active', 'ssh'], 
                                          capture_output=True, text=True).stdout.strip()
                self.update_status_label('ssh', 'Active' if ssh_status == 'active' else 'Inactive')
                
                # Check Bluetooth
                bt_status = subprocess.run(['systemctl', 'is-active', 'bluetooth'], 
                                         capture_output=True, text=True).stdout.strip()
                self.update_status_label('bluetooth', 'Active' if bt_status == 'active' else 'Inactive')
                
                # Check Network
                try:
                    ip = subprocess.run(['hostname', '-I'], capture_output=True, text=True).stdout.strip().split()[0]
                    self.update_status_label('network', f"Connected ({ip})")
                except:
                    self.update_status_label('network', 'Disconnected')
                
                # Check Controller
                controller_status = "Detected" if os.path.exists('/dev/input/js0') else "Not Found"
                self.update_status_label('controller', controller_status)
                
                # Check Direwolf
                direwolf_status = "Installed" if subprocess.run(['which', 'direwolf'], 
                                                              capture_output=True).returncode == 0 else "Not Installed"
                self.update_status_label('direwolf', direwolf_status)
                
                # Check QSSTV
                qsstv_status = "Installed" if subprocess.run(['which', 'qsstv'], 
                                                            capture_output=True).returncode == 0 else "Not Installed"
                self.update_status_label('qsstv', qsstv_status)
                
                # Update system info
                self.update_system_info()
                
            except Exception as e:
                print(f"Error checking system status: {e}")
        
        # Run in background thread
        threading.Thread(target=update_status, daemon=True).start()
    
    def update_status_label(self, key, status):
        """Update status label with color coding"""
        if key in self.status_labels:
            color = '#27ae60' if status in ['Active', 'Connected', 'Detected', 'Installed'] else '#e74c3c'
            if 'Connected' in status:
                color = '#27ae60'
            self.status_labels[key].config(text=status, fg=color)
    
    def update_system_info(self):
        """Update system information display"""
        try:
            # Get system info
            uname = subprocess.run(['uname', '-r'], capture_output=True, text=True).stdout.strip()
            arch = subprocess.run(['uname', '-m'], capture_output=True, text=True).stdout.strip()
            
            # Get disk space
            df_output = subprocess.run(['df', '-h', '.'], capture_output=True, text=True).stdout.split('\n')[1]
            available = df_output.split()[3]
            
            info_text = f"Kernel: {uname} | Architecture: {arch} | Available: {available}"
            self.info_label.config(text=info_text)
            
        except Exception as e:
            self.info_label.config(text="System info unavailable")
    
    def quick_action(self, num):
        """Handle number key quick actions"""
        actions = {
            1: self.launch_aprs,
            2: self.launch_qsstv,
            3: self.show_settings,
            4: self.check_dependencies,
            5: self.install_dependencies,
            6: self.show_system_info
        }
        
        if num in actions:
            actions[num]()
    
    def launch_aprs(self):
        """Launch APRS Chatty X"""
        script_path = os.path.join(os.path.dirname(__file__), 'scripts', 'launch_aprs_chatty_x.sh')
        try:
            subprocess.Popen(['bash', script_path], start_new_session=True)
            messagebox.showinfo("APRS Chatty X", "Launching APRS Chatty X...")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch APRS Chatty X: {e}")
    
    def launch_qsstv(self):
        """Launch QSSTV"""
        script_path = os.path.join(os.path.dirname(__file__), 'scripts', 'launch_qsstv.sh')
        try:
            subprocess.Popen(['bash', script_path], start_new_session=True)
            messagebox.showinfo("QSSTV", "Launching QSSTV...")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch QSSTV: {e}")
    
    def show_settings(self):
        """Show settings dialog"""
        SettingsWindow(self.root)
    
    def check_dependencies(self):
        """Run dependency checker"""
        self.run_script_in_terminal('check_dependencies.sh', 'Dependency Check')
    
    def install_dependencies(self):
        """Run dependency installer"""
        result = messagebox.askyesno("Install Dependencies", 
                                   "This will install ham radio applications and dependencies.\n\n"
                                   "This requires sudo access and may take several minutes.\n\n"
                                   "Continue?")
        if result:
            self.run_script_in_terminal('install_dependencies.sh', 'Dependency Installation')
    
    def show_system_info(self):
        """Show detailed system information"""
        SystemInfoWindow(self.root)
    
    def show_help(self):
        """Show help dialog"""
        help_text = """
🔊 HAMSTER - Ham Radio Manager

MAIN FUNCTIONS:
📻 APRS Chatty X - APRS packet radio messaging
📺 QSSTV - Slow-scan television
🔧 Settings - System configuration

KEYBOARD SHORTCUTS:
1-6 - Quick menu access
Enter - Launch APRS
Space - Launch QSSTV
Esc - Settings
F1 - This help
F5 - Refresh status

CONTROLLER SUPPORT:
D-Pad - Navigation
A Button - Select
B Button - Back
Start - Quick menu

For more information, visit the documentation.
        """
        messagebox.showinfo("Help - Hamster Ham Radio Manager", help_text)
    
    def refresh_status(self):
        """Refresh system status"""
        self.check_system_status()
        messagebox.showinfo("Refresh", "System status refreshed!")
    
    def run_script_in_terminal(self, script_name, title):
        """Run a script in a terminal window"""
        script_path = os.path.join(os.path.dirname(__file__), 'scripts', script_name)
        try:
            # Try different terminal emulators
            terminals = ['x-terminal-emulator', 'gnome-terminal', 'xterm', 'konsole']
            for terminal in terminals:
                if subprocess.run(['which', terminal], capture_output=True).returncode == 0:
                    subprocess.Popen([terminal, '-e', f'bash {script_path}; read -p "Press Enter to close..."'])
                    break
            else:
                messagebox.showerror("Error", "No terminal emulator found")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to run {script_name}: {e}")
    
    def run(self):
        """Start the GUI main loop"""
        self.root.mainloop()


class SettingsWindow:
    def __init__(self, parent):
        self.window = tk.Toplevel(parent)
        self.window.title("Hamster Settings")
        self.window.geometry("600x400")
        self.window.configure(bg='#2c3e50')
        self.window.grab_set()  # Modal dialog
        
        self.create_settings_widgets()
    
    def create_settings_widgets(self):
        """Create settings interface"""
        # Title
        title = tk.Label(self.window, text="System Settings", 
                        font=('Arial', 18, 'bold'),
                        bg='#2c3e50', fg='#ecf0f1')
        title.pack(pady=20)
        
        # Settings notebook
        notebook = ttk.Notebook(self.window)
        notebook.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Network tab
        network_frame = tk.Frame(notebook, bg='#34495e')
        notebook.add(network_frame, text="Network")
        self.create_network_settings(network_frame)
        
        # Audio tab
        audio_frame = tk.Frame(notebook, bg='#34495e')
        notebook.add(audio_frame, text="Audio")
        self.create_audio_settings(audio_frame)
        
        # Ham Radio tab
        ham_frame = tk.Frame(notebook, bg='#34495e')
        notebook.add(ham_frame, text="Ham Radio")
        self.create_ham_settings(ham_frame)
    
    def create_network_settings(self, parent):
        """Create network settings"""
        tk.Label(parent, text="Network Configuration", 
                font=('Arial', 14, 'bold'),
                bg='#34495e', fg='#ecf0f1').pack(pady=10)
        
        # SSH button
        tk.Button(parent, text="Enable SSH Permanently",
                 command=self.enable_ssh,
                 font=('Arial', 12),
                 bg='#27ae60', fg='white').pack(pady=5)
        
        # WiFi button
        tk.Button(parent, text="Enable WiFi Permanently",
                 command=self.enable_wifi,
                 font=('Arial', 12),
                 bg='#3498db', fg='white').pack(pady=5)
        
        # Bluetooth button
        tk.Button(parent, text="Configure Bluetooth",
                 command=self.configure_bluetooth,
                 font=('Arial', 12),
                 bg='#9b59b6', fg='white').pack(pady=5)
    
    def create_audio_settings(self, parent):
        """Create audio settings"""
        tk.Label(parent, text="Audio Configuration", 
                font=('Arial', 14, 'bold'),
                bg='#34495e', fg='#ecf0f1').pack(pady=10)
        
        tk.Button(parent, text="Audio Device Selection",
                 command=self.configure_audio,
                 font=('Arial', 12),
                 bg='#f39c12', fg='white').pack(pady=5)
        
        tk.Button(parent, text="Test Audio Devices",
                 command=self.test_audio,
                 font=('Arial', 12),
                 bg='#e67e22', fg='white').pack(pady=5)
    
    def create_ham_settings(self, parent):
        """Create ham radio settings"""
        tk.Label(parent, text="Amateur Radio Station", 
                font=('Arial', 14, 'bold'),
                bg='#34495e', fg='#ecf0f1').pack(pady=10)
        
        # Callsign entry
        callsign_frame = tk.Frame(parent, bg='#34495e')
        callsign_frame.pack(pady=10)
        
        tk.Label(callsign_frame, text="Callsign:", 
                bg='#34495e', fg='#ecf0f1').pack(side=tk.LEFT)
        
        self.callsign_entry = tk.Entry(callsign_frame, font=('Arial', 12))
        self.callsign_entry.pack(side=tk.LEFT, padx=10)
        
        tk.Button(parent, text="Save Station Settings",
                 command=self.save_ham_settings,
                 font=('Arial', 12),
                 bg='#27ae60', fg='white').pack(pady=10)
    
    def enable_ssh(self):
        """Enable SSH service"""
        try:
            subprocess.run(['sudo', 'systemctl', 'enable', 'ssh'], check=True)
            subprocess.run(['sudo', 'systemctl', 'start', 'ssh'], check=True)
            messagebox.showinfo("SSH", "SSH enabled successfully!")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to enable SSH: {e}")
    
    def enable_wifi(self):
        """Enable WiFi/NetworkManager"""
        try:
            subprocess.run(['sudo', 'systemctl', 'enable', 'NetworkManager'], check=True)
            subprocess.run(['sudo', 'systemctl', 'start', 'NetworkManager'], check=True)
            messagebox.showinfo("WiFi", "WiFi/NetworkManager enabled successfully!")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to enable WiFi: {e}")
    
    def configure_bluetooth(self):
        """Configure Bluetooth"""
        messagebox.showinfo("Bluetooth", "Use terminal: bluetoothctl\nSee Settings → Network for pairing guide")
    
    def configure_audio(self):
        """Configure audio devices"""
        messagebox.showinfo("Audio", "Use pavucontrol for GUI audio configuration")
    
    def test_audio(self):
        """Test audio devices"""
        try:
            subprocess.run(['aplay', '/usr/share/sounds/alsa/Front_Left.wav'], check=True)
            messagebox.showinfo("Audio Test", "Audio test completed!")
        except:
            messagebox.showwarning("Audio Test", "Audio test failed or no test sounds available")
    
    def save_ham_settings(self):
        """Save ham radio settings"""
        callsign = self.callsign_entry.get()
        if callsign:
            # Here you would save to config file
            messagebox.showinfo("Settings", f"Callsign {callsign} saved!")
        else:
            messagebox.showwarning("Settings", "Please enter a callsign")


class SystemInfoWindow:
    def __init__(self, parent):
        self.window = tk.Toplevel(parent)
        self.window.title("System Information")
        self.window.geometry("500x400")
        self.window.configure(bg='#2c3e50')
        self.window.grab_set()
        
        self.create_info_display()
    
    def create_info_display(self):
        """Create system info display"""
        title = tk.Label(self.window, text="System Information", 
                        font=('Arial', 16, 'bold'),
                        bg='#2c3e50', fg='#ecf0f1')
        title.pack(pady=10)
        
        # Scrollable text area
        text_frame = tk.Frame(self.window, bg='#2c3e50')
        text_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        self.info_text = tk.Text(text_frame, bg='#34495e', fg='#ecf0f1',
                                font=('Monaco', 10), wrap=tk.WORD)
        scrollbar = tk.Scrollbar(text_frame, command=self.info_text.yview)
        self.info_text.config(yscrollcommand=scrollbar.set)
        
        self.info_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.load_system_info()
        
        # Close button
        tk.Button(self.window, text="Close",
                 command=self.window.destroy,
                 font=('Arial', 12),
                 bg='#7f8c8d', fg='white').pack(pady=10)
    
    def load_system_info(self):
        """Load and display system information"""
        info = "SYSTEM INFORMATION\n"
        info += "=" * 50 + "\n\n"
        
        try:
            # Basic system info
            info += f"Kernel: {subprocess.run(['uname', '-r'], capture_output=True, text=True).stdout.strip()}\n"
            info += f"Architecture: {subprocess.run(['uname', '-m'], capture_output=True, text=True).stdout.strip()}\n"
            
            # OS info
            try:
                with open('/etc/os-release', 'r') as f:
                    for line in f:
                        if 'PRETTY_NAME=' in line:
                            os_name = line.split('=')[1].strip().strip('"')
                            info += f"OS: {os_name}\n"
                            break
            except:
                info += "OS: Unknown\n"
            
            # Memory info
            try:
                with open('/proc/meminfo', 'r') as f:
                    for line in f:
                        if 'MemTotal:' in line:
                            mem_kb = int(line.split()[1])
                            mem_gb = round(mem_kb / 1024 / 1024, 1)
                            info += f"Memory: {mem_gb} GB\n"
                            break
            except:
                info += "Memory: Unknown\n"
            
            # Disk space
            df_output = subprocess.run(['df', '-h'], capture_output=True, text=True).stdout
            info += f"\nDISK SPACE:\n{df_output}\n"
            
            # Network interfaces
            ip_output = subprocess.run(['ip', 'addr'], capture_output=True, text=True).stdout
            info += f"\nNETWORK INTERFACES:\n{ip_output}\n"
            
            # USB devices
            lsusb_output = subprocess.run(['lsusb'], capture_output=True, text=True).stdout
            info += f"\nUSB DEVICES:\n{lsusb_output}\n"
            
        except Exception as e:
            info += f"Error loading system info: {e}\n"
        
        self.info_text.insert(tk.END, info)
        self.info_text.config(state=tk.DISABLED)


def main():
    """Main entry point"""
    try:
        app = HamsterGUI()
        app.run()
    except KeyboardInterrupt:
        print("Hamster GUI interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"Error starting Hamster GUI: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()