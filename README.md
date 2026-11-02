# Strawboat

A cozy Godot game about catching arrows with a straw boat.

[Play in your browser](https://eric-schecter.github.io/straw-boat/)

## Play

Hold the left or right half of the screen to turn. Release to stop.
Catch enough arrows before the volley limit. Deflected arrows do not count.
A/D or arrow keys also turn; P pauses and R restarts.

## Develop

Open `project.godot` with **Godot 4.7.2** and press F5.

```sh
godot --headless --editor --import --quit
godot --headless -- --boat-test
./tools/export_web.sh
python3 -m http.server 8000 --directory build/web
```

Open `http://localhost:8000`. Web builds are published to GitHub Pages on pushes to `main`.

Boat and cover art were generated with AI. Nunito is licensed under the [SIL Open Font License](assets/fonts/OFL.txt).
