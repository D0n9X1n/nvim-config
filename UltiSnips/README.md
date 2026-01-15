# UltiSnips Directory

This directory contains all UltiSnips snippets from the original m-vim configuration, ready to use in Neovim.

## Included Snippets

### all.snippets
Global snippets available in all file types:
- `date` - Current date/time (YYYY-MM-DD HH:MM:SS)
- `datez` - Date with timezone
- `ddate` - Long date format (Month DD, YYYY)
- `sdate` - Short date (YYYY.MM.DD)
- `blog` - Blog post template (title, slug, date, category, tags)
- `/td` - TODO comment block
- `/mk` - MARK comment block

### python.snippets
Python programming snippets:
- `impall` - Import common modules
- `main` - Main block template
- `imp`, `from` - Import statements
- `p`, `pr`, `pri` - Print statements
- `s` - self. reference
- `def`, `defs` - Function definitions
- `init` - __init__ method
- `doc` - Docstring template
- Comprehensions: `fin`, `finif`
- Exception handling: `rai`, `tr`

### js.snippets
JavaScript/Node.js snippets:
- `log` - console.log() statement
- `react` - React library CDN links
- `bootstrap` - Bootstrap CSS/JS CDN links

### c.snippets
C programming snippets:
- `fori` - for loop with index
- `while` - while loop
- `if` - if statement
- `linuxc` - Linux C template with standard headers
- `fun` - Function definition
- `chead` - Header guard (#ifndef, #define, #endif)

### cpp.snippets
C++ with advanced algorithms:
- Loops: `fori`, `forj`, `fork`, `rfori`, `rforj`, `rfork`, `fort`
- I/O: `in`, `out`, `cout`
- ACM template: `acm` - Full competitive programming template
- Data structures: `vector`, `map`, `set`, `list`, `pq`
- Algorithms: `kmp`, `lcs`, `fib` - Ready-to-use algorithm implementations

### go.snippets
Go programming snippets:
- `pa` - Package and main function
- `fu` - Function definition
- `ty` - Struct type definition
- `err` - Error handling (if err != nil)
- `print`, `fpl`, `fpf` - Printing functions

### php.snippets
PHP snippets:
- `fori` - for loop
- `fore` - foreach loop
- `while` - while loop
- `sdd` - Debug functions (d, dd, json_return)

### snippets.snippets
Meta-snippets for creating new snippets:
- `snip` - Template for creating new snippets
- `ext` - Extends snippet

## Usage

### Expanding Snippets
1. Type snippet trigger (e.g., `date`)
2. Press `<Tab>` to expand
3. Use `<Tab>` to jump to next placeholder
4. Use `<S-Tab>` to jump to previous placeholder
5. Modify values as needed

### Examples

**Python:**
```python
# Type: impall + Tab
import os;
import shutil;
import glob;
# ... etc

# Type: main + Tab
if __name__ == '__main__':
    # cursor here
```

**C++:**
```cpp
// Type: acm + Tab
#include <algorithm>
#include <iostream>
// ... full ACM template
using namespace std;

int main() {
  ios::sync_with_stdio(false);
  // cursor here
  return 0;
}
```

**JavaScript:**
```js
// Type: log + Tab
console.log("");
// cursor here
```

## Editing Snippets

To edit or create custom snippets:
1. Press `,us` (leader key + 'u' + 's')
2. UltiSnips will open the snippet editor
3. Edit and save
4. Changes take effect immediately

## Adding Custom Snippets

You can add your own snippets to these files. Each snippet has the format:

```
snippet trigger
your code here with ${1:placeholder}
endsnippet
```

Example - Add to python.snippets:
```
snippet hello
print("Hello ${1:World}")
endsnippet
```

Then you can use it:
```
Type: hello + Tab
Output: print("Hello World")
```

## File Locations

- Configuration: `~/.config/nvim/snippets/`
- Fallback: honza/vim-snippets plugin provides additional snippets
- Plugin config: `~/.config/nvim/lua/config/plugins/ultisnips.lua`

## Compatibility

✅ Works with Neovim's UltiSnips plugin
✅ Same format as original m-vim snippets
✅ Fully compatible with Vim too
✅ No conversion needed - use as-is

---

All snippets are ready to use immediately after installation!
