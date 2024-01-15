const overlay = document.createElement('div')

overlay.style.position = 'fixed'
overlay.style.top = '0'
overlay.style.left = '0'
overlay.style.width = '100vw'
overlay.style.height = '100vh'
overlay.style.zIndex = '999999'
overlay.style.background = '#1f1f1f'
overlay.style.display = 'none'
overlay.style.placeItems = 'center'

overlay.innerHTML = `<div>Hello World</div>`

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

  //if (event.key == 'ArrowRight') {

    //i++

    //console.log(i)

    //overlay.children[0].replaceWith(images[i].element)

    //return

  //}

  //if (event.key == 'ArrowLeft') {

    //i--

    //console.log(i)

    //overlay.children[0].replaceWith(images[i].element)

    //return

  //}

  if (images.length && overlay.style.display != 'none') {

    if (event.key == 'ArrowRight') i++
    if (event.key == 'ArrowLeft') i--

    i = Math.max(Math.min(images.length - 1, i), 0)

    overlay.children[0].replaceWith(images[i].element)

  }

  if (event.key.toLocaleLowerCase() != 'g') return

  overlay.style.display = overlay.style.display == 'none' ? 'grid' : 'none'

})