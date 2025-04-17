# Import required libraries
import time
from mailjet_rest import Client
import psutil
import os
from datetime import datetime, timedelta
import platform
import socket

# Define mailjet credentials
api_key = os.environ.get("MAILJET_API_KEY")
api_secret = os.environ.get("MAILJET_SECRET_KEY")

# Define System thresholds
CPU_THRESHOLD = 2  # Percentage CPU usage to trigger alert
RAM_THRESHOLD = 8  # Percentage RAM usage to trigger alert
DISK_THRESHOLD = 1  # Percentage disk used to trigger alert

# Function to send email alert
def send_alert(subject, message):
    """Send email alert using Mailjet API."""
    # instantiate mailjet client
    mailjet = Client(auth=(api_key, api_secret), version='v3.1')
    data = {
        'Messages': [
            {
                "From": {
                    "Email": "Your monitoring email",  # Replace with your monitoring email
                    "Name": "System Monitor"
                },
                "To": [
                    {
                        "Email": "admin email",  # Replace with your admin email
                        "Name": "Admin"
                    }
                ],
                "Subject": subject,
                "HTMLPart": message
            }
        ]
    }
    try:
        result = mailjet.send.create(data=data)
        print(f"Email sent: {result.status_code}")
    except Exception as e:
        print(f"Failed to send email: {str(e)}")

def get_uptime():
    """Get system uptime in a human-readable format."""
    boot_time = psutil.boot_time()
    uptime = datetime.now() - datetime.fromtimestamp(boot_time)
    days = uptime.days
    hours, remainder = divmod(uptime.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{days}d {hours}h {minutes}m {seconds}s"

def get_system_metrics():
    """Collects various system metrics using psutil."""
    # Basic system info
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)
    os_info = platform.platform()
    
    # CPU metrics
    cpu_percent = psutil.cpu_percent(interval=1)
    cpu_count_logical = psutil.cpu_count()
    cpu_count_physical = psutil.cpu_count(logical=False)
    cpu_freq = psutil.cpu_freq()
    if cpu_freq:
        cpu_current_freq = round(cpu_freq.current, 2)
    else:
        cpu_current_freq = "N/A"
    cpu_load_avg = psutil.getloadavg()
    
    # Memory metrics
    ram = psutil.virtual_memory()
    swap = psutil.swap_memory()
    
    # Disk metrics
    disk = psutil.disk_usage('/')
    disk_io = psutil.disk_io_counters()
    
    # Network metrics
    net = psutil.net_io_counters()
    
    # Process and user metrics
    users = [user.name for user in psutil.users()]
    pids = psutil.pids()
    num_processes = len(pids)
    
    # Top 5 CPU-consuming processes
    top_processes = []
    for proc in sorted(psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']), 
                     key=lambda x: x.info['cpu_percent'] if x.info['cpu_percent'] else 0, 
                     reverse=True)[:5]:
        try:
            top_processes.append({
                'pid': proc.info['pid'],
                'name': proc.info['name'],
                'cpu_percent': proc.info['cpu_percent'],
                'memory_percent': proc.info['memory_percent'] if proc.info['memory_percent'] else 0
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    
    # System uptime
    uptime = get_uptime()
    boot_time = datetime.fromtimestamp(psutil.boot_time()).strftime("%Y-%m-%d %H:%M:%S")
    
    return {
        "hostname": hostname,
        "ip_address": ip_address,
        "os_info": os_info,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "uptime": uptime,
        "boot_time": boot_time,
        
        # CPU metrics
        "cpu_percent": cpu_percent,
        "cpu_count_logical": cpu_count_logical,
        "cpu_count_physical": cpu_count_physical,
        "cpu_current_freq": cpu_current_freq,
        "cpu_load_avg_1min": cpu_load_avg[0],
        "cpu_load_avg_5min": cpu_load_avg[1],
        "cpu_load_avg_15min": cpu_load_avg[2],
        
        # Memory metrics
        "ram_percent": ram.percent,
        "ram_used": round(ram.used / (1024 ** 3), 2),  # GB
        "ram_total": round(ram.total / (1024 ** 3), 2),  # GB
        "ram_free": round(ram.available / (1024 ** 3), 2),  # GB
        "swap_percent": swap.percent,
        "swap_used": round(swap.used / (1024 ** 3), 2),  # GB
        "swap_total": round(swap.total / (1024 ** 3), 2),  # GB
        
        # Disk metrics
        "disk_percent": disk.percent,
        "disk_free": round(disk.free / (1024 ** 3), 2),  # GB
        "disk_used": round(disk.used / (1024 ** 3), 2),  # GB
        "disk_total": round(disk.total / (1024 ** 3), 2),  # GB
        "disk_read_count": disk_io.read_count,
        "disk_write_count": disk_io.write_count,
        "disk_read_bytes": round(disk_io.read_bytes / (1024 ** 3), 2),  # GB
        "disk_write_bytes": round(disk_io.write_bytes / (1024 ** 3), 2),  # GB
        
        # Network metrics
        "network_bytes_sent": round(net.bytes_sent / (1024 ** 2), 2),  # MB
        "network_bytes_recv": round(net.bytes_recv / (1024 ** 2), 2),  # MB
        "network_packets_sent": net.packets_sent,
        "network_packets_recv": net.packets_recv,
        "network_errin": net.errin,
        "network_errout": net.errout,
        
        # Process metrics
        "logged_in_users": ", ".join(users) if users else "None",
        "running_processes": num_processes,
        "top_processes": top_processes,
    }

def get_status_color(value, threshold):
    """Returns color based on value relative to threshold."""
    if value >= threshold:
        return "#FF4136"  # Red for alert state
    elif value >= threshold * 0.7:
        return "#FF851B"  # Orange for warning state
    else:
        return "#2ECC40"  # Green for normal state

def create_progress_circle(percentage, color):
    """Creates an email-compatible circular progress indicator using HTML tables."""
    return f'''
    <table cellpadding="0" cellspacing="0" border="0" style="margin: 0 auto;">
        <tr>
            <td style="width: 100px; height: 100px; border-radius: 50%; background-color: {color}; 
                      text-align: center; vertical-align: middle; color: white; font-weight: bold; font-size: 22px;">
                {percentage}%
            </td>
        </tr>
    </table>
    '''

def get_meter_html(percentage, color):
    """Creates a simple meter visualization that works in email clients."""
    filled_bars = int(percentage / 10)
    empty_bars = 10 - filled_bars
    
    meter_html = '<div style="margin:10px 0; text-align:center; font-family:monospace; letter-spacing:2px;">'
    meter_html += f'<span style="color:{color}; font-weight:bold;">{"■" * filled_bars}</span>'
    meter_html += f'<span style="color:#dddddd;">{"■" * empty_bars}</span>'
    meter_html += '</div>'
    
    return meter_html

def create_horizontal_bar(value, max_value, color, height=15):
    """Creates an email-compatible horizontal bar chart."""
    percentage = min(100, (value / max_value) * 100)
    
    return f'''
    <div style="width:100%; background-color:#f0f0f0; border-radius:4px; height:{height}px; margin:5px 0;">
        <div style="width:{percentage}%; background-color:{color}; height:{height}px; border-radius:4px; 
                  text-align:right; line-height:{height}px; color:white; font-size:12px; font-weight:bold; padding-right:5px;">
            {value}
        </div>
    </div>
    '''

def format_size(size_bytes):
    """Format bytes to human-readable size."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 ** 2:
        return f"{size_bytes/1024:.2f} KB"
    elif size_bytes < 1024 ** 3:
        return f"{size_bytes/(1024**2):.2f} MB"
    else:
        return f"{size_bytes/(1024**3):.2f} GB"

def create_process_table(processes):
    """Creates an HTML table for top processes."""
    if not processes:
        return "<p>No process data available</p>"
    
    table_html = '''
    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse: collapse; margin-top: 10px;">
        <tr style="background-color: #34495E; color: white;">
            <th style="text-align: left; padding: 8px;">PID</th>
            <th style="text-align: left; padding: 8px;">Process Name</th>
            <th style="text-align: left; padding: 8px;">CPU %</th>
            <th style="text-align: left; padding: 8px;">Memory %</th>
        </tr>
    '''
    
    for i, proc in enumerate(processes):
        bg_color = "#f9f9f9" if i % 2 == 0 else "#ffffff"
        table_html += f'''
        <tr style="background-color: {bg_color};">
            <td style="padding: 8px; border-bottom: 1px solid #ddd;">{proc['pid']}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd;">{proc['name']}</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd;">{proc['cpu_percent']:.1f}%</td>
            <td style="padding: 8px; border-bottom: 1px solid #ddd;">{proc['memory_percent']:.1f}%</td>
        </tr>
        '''
    
    table_html += '</table>'
    return table_html

def create_stat_card(title, value, subtitle=None, icon=None, color="#3498DB"):
    """Creates a simple stat card."""
    icon_html = ""
    if icon:
        icon_html = f'<div style="font-size: 24px; margin-bottom: 5px;">{icon}</div>'
    
    subtitle_html = ""
    if subtitle:
        subtitle_html = f'<div style="font-size: 12px; color: #666;">{subtitle}</div>'
        
    return f'''
    <div style="background-color: white; border-left: 4px solid {color}; padding: 15px; 
               margin-bottom: 15px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
        <div style="font-size: 14px; color: #666; margin-bottom: 5px;">{title}</div>
        {icon_html}
        <div style="font-size: 20px; font-weight: bold; color: #333;">{value}</div>
        {subtitle_html}
    </div>
    '''

def main():
    """Main monitoring loop."""
    while True:
        metrics = get_system_metrics()
        alert_triggered = False
        
        # Check thresholds
        cpu_status = "alert" if metrics["cpu_percent"] > CPU_THRESHOLD else "normal"
        ram_status = "alert" if metrics["ram_percent"] > RAM_THRESHOLD else "normal"
        disk_status = "alert" if metrics["disk_percent"] > DISK_THRESHOLD else "normal"
        
        if cpu_status == "alert" or ram_status == "alert" or disk_status == "alert":
            alert_triggered = True
        
        # Set status colors
        cpu_color = get_status_color(metrics["cpu_percent"], CPU_THRESHOLD)
        ram_color = get_status_color(metrics["ram_percent"], RAM_THRESHOLD)
        disk_color = get_status_color(metrics["disk_percent"], DISK_THRESHOLD)
        
        # Create email content
        email_content = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>System Health Dashboard - {metrics['timestamp']}</title>
            <style>
                /* Base styles with email client compatibility */
                body {{
                    font-family: Arial, sans-serif;
                    margin: 0;
                    padding: 0;
                    color: #333333;
                    line-height: 1.4;
                    background-color: #f5f5f5;
                }}
                .header {{
                    background-color: #2C3E50;
                    color: white;
                    padding: 20px;
                    text-align: center;
                    border-radius: 8px 8px 0 0;
                    margin-bottom: 0;
                }}
                .content {{
                    padding: 20px;
                    background-color: #ffffff;
                    border: 1px solid #dddddd;
                    border-radius: 8px;
                    margin: 0 20px;
                }}
                .card {{
                    background-color: #ffffff;
                    border: 1px solid #dddddd;
                    border-radius: 8px;
                    padding: 15px;
                    margin-bottom: 20px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }}
                .headline {{
                    margin-top: 0;
                    margin-bottom: 10px;
                    color: #2C3E50;
                    font-weight: bold;
                    border-bottom: 1px solid #eee;
                    padding-bottom: 10px;
                }}
                .alert {{
                    background-color: #FFECEC;
                    border-left: 4px solid #FF4136;
                    padding: 10px;
                    margin-bottom: 10px;
                    color: #D8000C;
                }}
                .warning {{
                    background-color: #FFF8E1;
                    border-left: 4px solid #FF851B;
                    padding: 10px;
                    margin-bottom: 10px;
                    color: #9F6000;
                }}
                .normal {{
                    background-color: #E8F5E9;
                    border-left: 4px solid #2ECC40;
                    padding: 10px;
                    margin-bottom: 10px;
                    color: #4CAF50;
                }}
            </style>
        </head>
        <body>
            <div style="max-width: 800px; margin: 0 auto; background-color: #f5f5f5; padding: 20px;">
                <!-- Header Section -->
                <div style="background-color: #2C3E50; color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">
                    <h1 style="margin: 0; font-size: 24px;">System Health Dashboard</h1>
                    <p style="margin: 5px 0 0 0; font-size: 14px;">{metrics['timestamp']}</p>
                </div>
                
                <!-- System Information -->
                <div style="background-color: #ffffff; padding: 20px; border: 1px solid #dddddd; margin-bottom: 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                        <tr>
                            <td width="33%" style="padding: 10px; vertical-align: top;">
                                {create_stat_card("Hostname", metrics['hostname'], "Server Identity", "🖥️", "#3498DB")}
                            </td>
                            <td width="33%" style="padding: 10px; vertical-align: top;">
                                {create_stat_card("IP Address", metrics['ip_address'], "Network Location", "🌐", "#3498DB")}
                            </td>
                            <td width="33%" style="padding: 10px; vertical-align: top;">
                                {create_stat_card("Uptime", metrics['uptime'], "Since Boot", "⏱️", "#3498DB")}
                            </td>
                        </tr>
                        <tr>
                            <td colspan="3" style="padding: 10px;">
                                {create_stat_card("Operating System", metrics['os_info'], "System Platform", "💻", "#3498DB")}
                            </td>
                        </tr>
                    </table>
                </div>
                
                <!-- Status Overview -->
                <div style="background-color: #ffffff; padding: 20px; border: 1px solid #dddddd; margin-bottom: 20px;">
                    <h2 style="margin-top: 0; color: #2C3E50; border-bottom: 1px solid #eee; padding-bottom: 10px;">Status Overview</h2>
                    
                    <!-- Alert Messages -->
                    <div class="{cpu_status}" style="margin-bottom: 10px;">
                        <strong>CPU Usage:</strong> {metrics['cpu_percent']}% 
                        <span style="float:right;">(Threshold: {CPU_THRESHOLD}%)</span>
                    </div>
                    
                    <div class="{ram_status}" style="margin-bottom: 10px;">
                        <strong>RAM Usage:</strong> {metrics['ram_percent']}% 
                        <span style="float:right;">(Threshold: {RAM_THRESHOLD}%)</span>
                    </div>
                    
                    <div class="{disk_status}" style="margin-bottom: 10px;">
                        <strong>Disk Usage:</strong> {metrics['disk_percent']}% 
                        <span style="float:right;">(Threshold: {DISK_THRESHOLD}%)</span>
                    </div>
                </div>
                
                <!-- Resource Usage Summary with Email-Compatible Visualizations -->
                <div style="background-color: #ffffff; padding: 20px; border: 1px solid #dddddd; margin-bottom: 20px;">
                    <h2 style="margin-top: 0; color: #2C3E50; border-bottom: 1px solid #eee; padding-bottom: 10px;">Resource Usage Summary</h2>
                    
                    <!-- Email-compatible table layout for the three metrics -->
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                        <tr>
                            <td width="33.33%" style="text-align: center; padding: 10px; vertical-align: top;">
                                <p style="font-weight: bold; color: #555; margin-bottom: 10px; text-transform: uppercase; font-size: 14px;">CPU Usage</p>
                                {create_progress_circle(metrics['cpu_percent'], cpu_color)}
                                {get_meter_html(metrics['cpu_percent'], cpu_color)}
                                <p style="font-size: 12px; color: #666;">
                                    {metrics['cpu_count_physical']} physical cores<br>
                                    {metrics['cpu_count_logical']} logical cores
                                </p>
                            </td>
                            <td width="33.33%" style="text-align: center; padding: 10px; vertical-align: top;">
                                <p style="font-weight: bold; color: #555; margin-bottom: 10px; text-transform: uppercase; font-size: 14px;">RAM Usage</p>
                                {create_progress_circle(metrics['ram_percent'], ram_color)}
                                {get_meter_html(metrics['ram_percent'], ram_color)}
                                <p style="font-size: 12px; color: #666;">
                                    {metrics['ram_used']} GB used<br>
                                    of {metrics['ram_total']} GB total
                                </p>
                            </td>
                            <td width="33.33%" style="text-align: center; padding: 10px; vertical-align: top;">
                                <p style="font-weight: bold; color: #555; margin-bottom: 10px; text-transform: uppercase; font-size: 14px;">Disk Usage</p>
                                {create_progress_circle(metrics['disk_percent'], disk_color)}
                                {get_meter_html(metrics['disk_percent'], disk_color)}
                                <p style="font-size: 12px; color: #666;">
                                    {metrics['disk_used']} GB used<br>
                                    of {metrics['disk_total']} GB total
                                </p>
                            </td>
                        </tr>
                    </table>
                </div>
                
                <!-- Detailed CPU Metrics -->
                <div style="background-color: #ffffff; padding: 20px; border: 1px solid #dddddd; margin-bottom: 20px;">
                    <h2 style="margin-top: 0; color: #2C3E50; border-bottom: 1px solid #eee; padding-bottom: 10px;">
                        <span style="display: inline-block; width: 24px; height: 24px; border-radius: 50%; background-color: {cpu_color}; vertical-align: middle; margin-right: 10px;"></span>
                        CPU Details
                    </h2>
                    
                    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse: collapse;">
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd; width: 40%;">CPU Usage</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd; width: 60%;">
                                {metrics['cpu_percent']}% ({metrics['cpu_count_physical']} cores)
                                {get_meter_html(metrics['cpu_percent'], cpu_color)}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Current Frequency</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['cpu_current_freq']} MHz</td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Load Average (1 min)</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['cpu_load_avg_1min']:.2f}</td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Load Average (5 min)</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['cpu_load_avg_5min']:.2f}</td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Load Average (15 min)</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['cpu_load_avg_15min']:.2f}</td>
                        </tr>
                    </table>
                </div>
                
                <!-- Detailed Memory Metrics -->
                <div style="background-color: #ffffff; padding: 20px; border: 1px solid #dddddd; margin-bottom: 20px;">
                    <h2 style="margin-top: 0; color: #2C3E50; border-bottom: 1px solid #eee; padding-bottom: 10px;">
                        <span style="display: inline-block; width: 24px; height: 24px; border-radius: 50%; background-color: {ram_color}; vertical-align: middle; margin-right: 10px;"></span>
                        Memory Details
                    </h2>
                    
                    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse: collapse;">
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd; width: 40%;">RAM Usage</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd; width: 60%;">
                                {metrics['ram_percent']}%
                                {get_meter_html(metrics['ram_percent'], ram_color)}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Total RAM</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['ram_total']} GB</td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Used RAM</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['ram_used']} GB</td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Free RAM</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['ram_free']} GB</td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Swap Usage</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">
                                {metrics['swap_percent']}%
                                {get_meter_html(metrics['swap_percent'], get_status_color(metrics['swap_percent'], RAM_THRESHOLD))}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Swap Total</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['swap_total']} GB</td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Swap Used</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['swap_used']} GB</td>
                        </tr>
                    </table>
                </div>
                
                <!-- Detailed Disk Metrics -->
                <div style="background-color: #ffffff; padding: 20px; border: 1px solid #dddddd; margin-bottom: 20px;">
                    <h2 style="margin-top: 0; color: #2C3E50; border-bottom: 1px solid #eee; padding-bottom: 10px;">
                        <span style="display: inline-block; width: 24px; height: 24px; border-radius: 50%; background-color: {disk_color}; vertical-align: middle; margin-right: 10px;"></span>
                        Disk Details
                    </h2>
                    
                    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse: collapse;">
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd; width: 40%;">Disk Usage</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd; width: 60%;">
                                {metrics['disk_percent']}%
                                {get_meter_html(metrics['disk_percent'], disk_color)}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Total Space</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['disk_total']} GB</td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Used Space</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['disk_used']} GB</td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Free Space</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['disk_free']} GB</td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Read Operations</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['disk_read_count']:,}</td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Write Operations</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{metrics['disk_write_count']:,}</td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Read Bytes</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{format_size(metrics['disk_read_bytes'])}</td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Write Bytes</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">{format_size(metrics['disk_write_bytes'])}</td>
                        </tr>
                    </table>
                </div>
                <!-- Network Metrics -->
                <div style="background-color: #ffffff; padding: 20px; border: 1px solid #dddddd; margin-bottom: 20px;">
                    <h2 style="margin-top: 0; color: #2C3E50; border-bottom: 1px solid #eee; padding-bottom: 10px;">
                        Network Details
                    </h2>
                    
                    <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse: collapse;">
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd; width: 40%;">Bytes Sent</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd; width: 60%;">
                                {format_size(metrics['network_bytes_sent'])}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Bytes Received</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">
                                {format_size(metrics['network_bytes_recv'])}
                            </td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Packets Sent</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">
                                {metrics['network_packets_sent']:,}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Packets Received</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">
                                {metrics['network_packets_recv']:,}
                            </td>
                        </tr>
                        <tr style="background-color: #f9f9f9;">
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Errors In</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">
                                {metrics['network_errin']:,}
                            </td>
                        </tr>
                        <
                        <tr>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">Errors Out</td>
                            <td style="padding: 12px; border-bottom: 1px solid #ddd;">
                                {metrics['network_errout']:,}
                            </td>
                        </tr>
                    </table>
                </div>
                <!-- Top Processes -->
                <div style="background-color: #ffffff; padding: 20px; border: 1px solid #dddddd; margin-bottom: 20px;">
                    <h2 style="margin-top: 0; color: #2C3E50; border-bottom: 1px solid #eee; padding-bottom: 10px;">
                        Top Processes
                    </h2>
                    
                    {create_process_table(metrics['top_processes'])}
                </div>
                <!-- Footer -->
                <div style="text-align: center; padding: 20px; font-size: 12px; color: #999999;">
                    <p style="margin: 0;">This is an automated email. Please do not reply.</p>
                    <p style="margin: 0;">&copy; {datetime.now().year} System Monitor</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        # Send email if alert triggered
        if alert_triggered:
            subject = f"⚠️ ALERT: System Resources Critical - {metrics['timestamp']}"
            send_alert(subject, email_content)
        else:
            print(f"[{metrics['timestamp']}] All system metrics are within normal limits.")

        time.sleep(60)  # Check every minute

if __name__ == "__main__":
    # Ensure Mailjet API keys are set
    if not os.environ.get("MAILJET_API_KEY") or not os.environ.get("MAILJET_SECRET_KEY"):
        print("Error: Mailjet API keys not found in environment variables.")
    else:
        main()
