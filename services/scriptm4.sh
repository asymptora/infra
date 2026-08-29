contador=1

while true; do
    echo "$(date) - linha $contador"
    contador=$((contador + 1))
    sleep 1
done
