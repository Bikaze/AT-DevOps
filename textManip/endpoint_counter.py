import re


def count_endpoints(filename):
    """
    Count the number of times each HTTP endpoint was accessed from a log file.

    This function parses a log file and counts the number of accesses for each unique endpoint path.
    The log file is expected to contain lines with HTTP request information in the format:
    "METHOD /endpoint/path HTTP/version".

    Parameters
    ----------
    filename : str
        Path to the log file to be analyzed.

    Returns
    -------
    dict
        A dictionary where keys are endpoint paths (str) and values are the corresponding access counts (int).

    Example
    -------
    endpoint_counts = count_endpoints("access.log")
    print(endpoint_counts)
    """
    endpoint_count = {}

    # Pattern to extract HTTP method and endpoint from log
    # Matches: "GET /path/to/endpoint HTTP/1.1" or "POST /api/users HTTP/1.1"
    endpoint_pattern = r'"[A-Z]+ ([^\s]+) HTTP'

    with open(filename, "r") as file:
        for line in file:
            match = re.search(endpoint_pattern, line)
            if match:
                endpoint = match.group(1)
                if endpoint in endpoint_count:
                    endpoint_count[endpoint] += 1
                else:
                    endpoint_count[endpoint] = 1

    return endpoint_count


# Usage
if __name__ == "__main__":
    log_file = "NodeJsApp.log"
    results = count_endpoints(log_file)

    # Sort by access count (highest first)
    sorted_endpoints = sorted(results.items(), key=lambda x: x[1], reverse=True)

    for endpoint, count in sorted_endpoints:
        print(f"{endpoint}: {count}")
