import re
from collections import defaultdict

def analyze_user_agents(filename):
    """
    Analyzes a web server log file to count the number of requests made by each unique user agent.

    This function reads a log file line by line, attempts to extract the user agent string from each line
    using several common log patterns, and counts how many times each user agent appears. User agents are
    identifiers sent by browsers, bots, or other clients to indicate what software is making the request.
    If a user agent cannot be extracted from a line, the line is counted as skipped, and a debug message is printed.
    At the end of processing, debug information about the total lines processed, lines with user agents, and
    lines skipped is printed.

    Args:
        filename (str): The path to the log file to analyze.

    Returns:
        dict: A dictionary where the keys are user agent strings and the values are the number of requests
              made by each user agent.

    Example:
        >>> user_agents = analyze_user_agents('access.log')
        >>> for agent, count in user_agents.items():
        ...     print(f"{agent}: {count}")

        >>> counts = analyze_user_agents('access.log')
        >>> print(counts)
        {'Mozilla/5.0 ...': 123, 'curl/7.68.0': 45, ...}

    Notes:
        - This function is useful for understanding what browsers, bots, or tools are accessing your server.
        - The function prints debug information to the console for skipped lines and summary statistics.
        - The log file should be in a standard format (such as Apache or Nginx access logs) for best results.
    """
    user_agent_counts = defaultdict(int)
    total_lines = 0
    skipped_lines = 0
    
    # Common user agent patterns in log files
    user_agent_patterns = [
        r'"([^"]*)"[^"]*$',  # Last quoted string in line
        r'" "([^"]*)"$',     # After response code, before end
        r'"[^"]*" "([^"]*)"$',  # Standard Apache format
        r'"[^"]*" \d+ \d+ "([^"]*)"$'  # With response size
    ]
    
    with open(filename, 'r') as file:
        for line in file:
            total_lines += 1
            user_agent = None
            
            # Try each pattern to extract user agent
            for pattern in user_agent_patterns:
                match = re.search(pattern, line)
                if match:
                    candidate = match.group(1).strip()
                    # Validate it looks like a user agent
                    if candidate and not candidate.isdigit() and len(candidate) > 1:
                        user_agent = candidate
                        break
            
            # If no pattern worked, try finding Mozilla or other common UA indicators
            if not user_agent:
                mozilla_match = re.search(r'(Mozilla[^"]*)', line)
                if mozilla_match:
                    user_agent = mozilla_match.group(1).strip()
            
            # Count the user agent or track skipped lines
            if user_agent and user_agent != '-':
                user_agent_counts[user_agent] += 1
            else:
                skipped_lines += 1
                print(f"DEBUG: Skipped line {total_lines}: {line.strip()}")
    
    print(f"DEBUG: Total lines processed: {total_lines}")
    print(f"DEBUG: Lines with user agents: {sum(user_agent_counts.values())}")
    print(f"DEBUG: Lines skipped: {skipped_lines}")
    
    return dict(user_agent_counts)

def categorize_user_agents(user_agent_counts):
    """
    Categorize user agents into types (browser, bot, mobile, etc.)
    """
    categories = defaultdict(int)
    
    for user_agent, count in user_agent_counts.items():
        ua_lower = user_agent.lower()
        
        # Categorize based on common patterns
        if any(bot in ua_lower for bot in ['bot', 'crawler', 'spider', 'scraper']):
            categories['Bots/Crawlers'] += count
        elif any(browser in ua_lower for browser in ['chrome', 'firefox', 'safari', 'edge']):
            categories['Web Browsers'] += count
        elif any(mobile in ua_lower for mobile in ['mobile', 'android', 'iphone', 'ipad']):
            categories['Mobile Devices'] += count
        elif any(tool in ua_lower for tool in ['curl', 'wget', 'python', 'java']):
            categories['API/Tools'] += count
        elif 'mozilla' in ua_lower:
            categories['Mozilla-based'] += count
        else:
            categories['Other'] += count
    
    return dict(categories)

def display_user_agent_analysis(user_agent_counts):
    """Display user agent analysis results"""
    if not user_agent_counts:
        print("No user agents found in log file")
        return
    
    print("User Agent Request Analysis")
    print("=" * 50)
    
    # Show all user agents
    sorted_agents = sorted(user_agent_counts.items(), key=lambda x: x[1], reverse=True)
    
    print("\nAll User Agents by Request Count:")
    print("-" * 50)
    for i, (agent, count) in enumerate(sorted_agents, 1):
        print(f"{i:2d}. Requests: {count}")
        print(f"    Full User Agent: {agent}")
        print()
    
    # Show categories
    categories = categorize_user_agents(user_agent_counts)
    print("\nUser Agent Categories:")
    print("-" * 30)
    for category, count in sorted(categories.items(), key=lambda x: x[1], reverse=True):
        print(f"{category}: {count} requests")
    
    print(f"\nTotal unique user agents: {len(user_agent_counts)}")
    print(f"Total requests analyzed: {sum(user_agent_counts.values())}")

if __name__ == "__main__":
    log_file = "NodeJsApp.log"  # Replace with your log file path
    results = analyze_user_agents(log_file)
    display_user_agent_analysis(results)