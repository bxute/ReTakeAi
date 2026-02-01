#!/bin/bash
echo "🔍 Monitoring for crashes... Tap 'Audio Processor Test' now"
echo ""
xcrun simctl spawn booted log stream --predicate 'process == "ReTakeAi" AND messageType == "Error"' --level debug 2>&1 | grep -A10 -i "fatal\|crash\|exception\|assert"
