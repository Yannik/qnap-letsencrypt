**Platform/Firmware Information:**

```
Run
grep -e ^Platform -e ^DISPLAY_NAME  /etc/platform.conf
grep -e ^Version -e ^Build -e Model -e "\[" /etc/default_config/uLinux.conf | grep -v "\[System\]" | awk '1;/\[/{exit}' |grep -v "\["

and paste it here!
```

**Issue Summary (provide relevant error messages and log output):**
