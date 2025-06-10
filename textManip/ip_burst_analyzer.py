import re
from datetime import datetime
from collections import defaultdict

def analyze_ip_request_windows(filename):
    """
    Analyze a log file to determine, for each IP address, the maximum number of requests
    observed within any 10-second window after the first request from that IP.

    Args:
        filename (str): Path to the log file. Each line should contain an IP address and a timestamp.

    Supported Timestamp Formats:
        - [25/Dec/2023:10:15:30]   (Apache)
        - 2023-12-25 10:15:30      (ISO)
        - 25/12/2023 10:15:30      (European)

    Returns:
        dict: Mapping of IP address (str) to max requests (int) in any 10-second window after the first request.
              If an IP has only one request, its value will be 0.

    Notes:
        - Only the first IP per line is considered.
        - Lines without a recognizable IP or timestamp are ignored.
    """
    ip_requests = defaultdict(list)
    ip_pattern = r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b|\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b|\b(?:[0-9a-fA-F]{1,4}:)*::[0-9a-fA-F]{0,4}(?::[0-9a-fA-F]{1,4})*\b'
    timestamp_patterns = [
        r'\[(\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2})',  # [25/Dec/2023:10:15:30
        r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})',   # 2023-12-25 10:15:30
        r'(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2})',   # 25/12/2023 10:15:30
    ]
    with open(filename, 'r') as file:
        for line in file:
            ips = re.findall(ip_pattern, line)
            if not ips:
                continue
            ip = ips[0]
            timestamp = None
            for pattern in timestamp_patterns:
                match = re.search(pattern, line)
                if match:
                    timestamp_str = match.group(1)
                    try:
                        if '/' in timestamp_str and ':' in timestamp_str and timestamp_str.count('/') == 2 and timestamp_str.count(':') == 2:
                            timestamp = datetime.strptime(timestamp_str, '%d/%m/%Y %H:%M:%S')
                        elif '/' in timestamp_str and ':' in timestamp_str:
                            timestamp = datetime.strptime(timestamp_str, '%d/%b/%Y:%H:%M:%S')
                        elif '-' in timestamp_str:
                            timestamp = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
                        break
                    except ValueError:
                        continue
            if timestamp:
                ip_requests[ip].append(timestamp)
    results = {}
    for ip, timestamps in ip_requests.items():
        if len(timestamps) < 2:
            results[ip] = 0
            continue
        timestamps.sort()
        window_counts = []
        for i, start_time in enumerate(timestamps):
            count = 0
            for j in range(i + 1, len(timestamps)):
                time_diff = (timestamps[j] - start_time).total_seconds()
                if time_diff <= 10:
                    count += 1
                else:
                    break
            if count > 0:
                window_counts.append(count)
        results[ip] = max(window_counts) if window_counts else 0
    return results

def display_window_analysis(results):
    """
    Display results sorted by highest request count.
    """
    if not results:
        print("No IP addresses with timestamps found")
        return
    print("IP Address Request Window Analysis (10-second windows)")
    print("=" * 55)
    sorted_results = sorted(results.items(), key=lambda x: x[1], reverse=True)
    for ip, max_requests in sorted_results:
        if max_requests > 0:
            print(f"{ip}: {max_requests} requests after first in 10s window")
    zero_count = sum(1 for count in results.values() if count == 0)
    if zero_count > 0:
        print(f"\n{zero_count} IPs had no burst activity (single requests only)")

if __name__ == "__main__":
    log_file = "NodeJsApp.log"  # Replace with your log file path
    results = analyze_ip_request_windows(log_file)
    display_window_analysis(results)
