"""Add line numbers before each line of text from test.bas"""

def add_line_numbers(input_file, output_file=None):
    """
    Read a file and add line numbers before each line.
    
    Args:
        input_file: Path to the input file
        output_file: Path to the output file (if None, prints to stdout)
    """
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    # Add line numbers to each line
    numbered_lines = []
    line_num = 100
    for line in lines:
        # Skip empty lines or lines with only whitespace
        if line.strip():
            numbered_line = f"{line_num:4d} {line}"
            numbered_lines.append(numbered_line)
            line_num += 5
        else:
            numbered_lines.append(line)
    
    # Write to output file or print to stdout
    if output_file:
        with open(output_file, 'w') as f:
            f.writelines(numbered_lines)
        print(f"Output written to {output_file}")
    else:
        for line in numbered_lines:
            print(line, end='')


if __name__ == "__main__":
    # Read test.bas and add line numbers
    input_file = "sbterm2.bas"
    output_file = "sbterm.bas"  # Change to None to print to stdout
    
    add_line_numbers(input_file, output_file)
