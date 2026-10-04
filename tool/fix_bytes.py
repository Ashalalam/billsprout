import os
import glob

replacements = [
    ('\xc3\xa2\xe2\x80\x9a\xc2\xb9', '\xe2\x82\xb9'),
    ('\xc3\xa2\xe2\x82\xac\xe2\x80\x9c', '\xe2\x80\x94'),
    ('\xc3\xa2\xe2\x82\xac\xe2\x80\x9d', '\xe2\x80\x93'),
    ('\xc3\xa2\xe2\x82\xac\xc2\xa2', '\xe2\x80\xa2'),
    ('\xc3\x82\xc2\xb7', '\xc2\xb7'),
    ('\xc3\xa2\xe2\x80\x9c\xc6\x92', '\xe2\x94\x82'),
    ('\xc3\xa2\xe2\x80\x9c\xe2\x82\xac', '\xe2\x94\x80'),
    ('\xc3\xa2\xe2\x80\xa6', '\xe2\x80\xa6'),
    ('\xc3\x83\xe2\x80\x94', '\xc3\x97'),
]

dart_files = []
for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            dart_files.append(os.path.join(root, file))

print('Found ' + str(len(dart_files)) + ' Dart files')

fixed = 0
total_replacements = 0

for filepath in dart_files:
    try:
        with open(filepath, 'rb') as f:
            data = f.read()
        original = data
        file_replacements = 0
        
        for pattern, replacement in replacements:
            count = data.count(pattern)
            if count > 0:
                data = data.replace(pattern, replacement)
                file_replacements += count
        
        if data != original:
            with open(filepath, 'wb') as f:
                f.write(data)
            fixed += 1
            total_replacements += file_replacements
            print('Fixed: ' + filepath + ' (' + str(file_replacements) + ' replacements)')
    except Exception as e:
        print('Error: ' + filepath + ': ' + str(e))

print('')
print('=== Summary ===')
print('Files fixed: ' + str(fixed))
print('Total replacements: ' + str(total_replacements))
print('')
print('Done!')
