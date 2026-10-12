// Structured PETSCII records, padded names; sizes are illustrative KiB.
mock_left:
.byte TYPE_DIR, FLAG_READONLY
.word 0
.text "ARCADE              "
.byte TYPE_DIR, FLAG_READONLY
.word 0
.text "DEMOS               "
.byte TYPE_FILE, FLAG_READONLY
.word 14
.text "VYPER.D81           "
.byte TYPE_FILE, FLAG_READONLY
.word 21
.text "START.PRG           "
.byte TYPE_FILE, FLAG_READONLY
.word 28
.text "MUSIC.MOD           "
.byte TYPE_DIR, FLAG_READONLY
.word 0
.text "TOOLS               "
.byte TYPE_FILE, FLAG_READONLY
.word 42
.text "README.TXT          "
.byte TYPE_FILE, FLAG_READONLY
.word 49
.text "INTRO.PRG           "
.byte TYPE_FILE, FLAG_READONLY
.word 56
.text "RACER.D81           "
.byte TYPE_FILE, FLAG_READONLY
.word 63
.text "PUZZLE.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 70
.text "SPRITES.BIN         "
.byte TYPE_FILE, FLAG_READONLY
.word 77
.text "SOUND.SID           "
.byte TYPE_DIR, FLAG_READONLY
.word 0
.text "ADVENTURE           "
.byte TYPE_FILE, FLAG_READONLY
.word 91
.text "LEVELS.DAT          "
.byte TYPE_FILE, FLAG_READONLY
.word 98
.text "EDITOR.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 105
.text "DISK2.D81           "
.byte TYPE_FILE, FLAG_READONLY
.word 112
.text "MANUAL.TXT          "
.byte TYPE_FILE, FLAG_READONLY
.word 119
.text "PLAYER.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 126
.text "PICTURE.IFF         "
.byte TYPE_FILE, FLAG_READONLY
.word 133
.text "BACKUP.D81          "
.byte TYPE_DIR, FLAG_READONLY
.word 0
.text "UTILS               "
.byte TYPE_FILE, FLAG_READONLY
.word 147
.text "LAST.PRG            "
.byte TYPE_FILE, FLAG_READONLY
.word 154
.text "END.SEQ             "
.byte TYPE_FILE, FLAG_READONLY
.word 161
.text "FINAL.D81           "
mock_right:
.byte TYPE_FILE, FLAG_READONLY
.word 0
.text "HELLO.PRG           "
.byte TYPE_FILE, FLAG_READONLY
.word 7
.text "TEST.PRG            "
.byte TYPE_FILE, FLAG_READONLY
.word 14
.text "DATA.SEQ            "
.byte TYPE_DIR, FLAG_READONLY
.word 0
.text "GAMES               "
.byte TYPE_FILE, FLAG_READONLY
.word 28
.text "DEMO.PRG            "
.byte TYPE_FILE, FLAG_READONLY
.word 35
.text "NOTES.SEQ           "
.byte TYPE_FILE, FLAG_READONLY
.word 42
.text "LOADER.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 49
.text "SAVE.USR            "
.byte TYPE_DIR, FLAG_READONLY
.word 0
.text "TOOLS               "
.byte TYPE_FILE, FLAG_READONLY
.word 63
.text "SPRITES.SEQ         "
.byte TYPE_FILE, FLAG_READONLY
.word 70
.text "SOUND.PRG           "
.byte TYPE_FILE, FLAG_READONLY
.word 77
.text "README.SEQ          "
.byte TYPE_FILE, FLAG_READONLY
.word 84
.text "LEVEL1.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 91
.text "LEVEL2.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 98
.text "LEVEL3.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 105
.text "LEVEL4.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 112
.text "LEVEL5.PRG          "
.byte TYPE_FILE, FLAG_READONLY
.word 119
.text "LAST.PRG            "
