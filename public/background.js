const overlay = document.createElement('div')

overlay.style.position = 'fixed'
overlay.style.top = '0'
overlay.style.left = '0'
overlay.style.width = '100vw'
overlay.style.height = '100vh'
overlay.style.zIndex = '999999'
overlay.style.background = 'red'
overlay.style.display = 'none'

overlay.ondrop = ((event) => {

  event.preventDefault()

  const files = event.dataTransfer.files

  for (const file of files) {

    if (!file.type.startsWith('image/')) continue

    const img = document.createElement('img')

    img.src = URL.createObjectURL(file)
    img.draggable = false

    overlay.appendChild(img)

  }

})

overlay.ondragover  = ((event) => event.preventDefault())
overlay.ondrag = ((event) => event.preventDefault())

document.body.appendChild(overlay)

window.addEventListener('keydown', (event) => {

  if (event.key.toLocaleLowerCase() != 'g') return

  overlay.style.display = overlay.style.display == 'block' ? 'none' : 'block'

})