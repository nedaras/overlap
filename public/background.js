const overlay = document.createElement('div')
const header = document.createElement('header')

overlay.style.position = 'fixed'
overlay.style.top = '0'
overlay.style.left = '0'
overlay.style.width = '100vw'
overlay.style.height = '100vh'
overlay.style.zIndex = '999999'
overlay.style.background = '#1f1f1f'
overlay.style.display = 'none'
overlay.style.placeItems = 'center'

overlay.innerHTML = `<div style="color: #f1f1f1; font-family: sans-serif; font-size: min(4vw, 32px);" >Drop Image Here</div>`

let i = 0
const images = []

overlay.ondrop = ((event) => {

  event.preventDefault()

  const files = event.dataTransfer.files

  for (const file of files) {

    if (!file.type.startsWith('image/')) continue

    const img = document.createElement('img')

    img.src = URL.createObjectURL(file)
    img.draggable = false

    img.style.maxWidth = '100%'
    img.style.maxHeight = '100vh'
    img.style.transition = 'transform 0.35s ease';

    i = images.length
    images.push({
      name: file.name,
      element: img
    })

    overlay.children[0].replaceWith(img)

  }

})

overlay.ondragover  = ((event) => event.preventDefault())
overlay.ondrag = ((event) => event.preventDefault())

document.body.appendChild(overlay)

window.addEventListener('keydown', (event) => {

  if (images.length && overlay.style.display != 'none') {

    if (event.key == 'ArrowRight') i++
    if (event.key == 'ArrowLeft') i--

    i = Math.max(Math.min(images.length - 1, i), 0)

    overlay.children[0].replaceWith(images[i].element)

  }

  if (!(event.key == 'Shift' && event.location == 2)) return

  overlay.style.display = overlay.style.display == 'none' ? 'grid' : 'none'

})

let zoomLevel = 1;
overlay.addEventListener('wheel', (event) => {
  if (images.length && overlay.style.display !== 'none') {
    const img = images[i].element;

    zoomLevel += event.deltaY > 0 ? -(0.1 * zoomLevel) : (0.1 * zoomLevel);

    zoomLevel = Math.max(1, Math.min(zoomLevel, 50))

    img.style.transform = `scale(${zoomLevel})`;

  }
})
