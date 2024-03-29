// TODO: we gon have to use like wrapper for image so we could animate scale and transform separate

const container = document.getElementById('root')
const image = document.getElementById('image')

const images = []
let currentImage = 0

function saveImage(image) {

	const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))

	currentImage = images.length

	images.push({ src: image.src, matrix })

}

function loadImage(index) {

	const { src, matrix } = images[index]

	currentImage = index
	scale = matrix.a

	image.style.transform = `matrix(${scale}, 0, 0, ${scale}, ${matrix.m41}, ${matrix.m42})`
	image.src = src

}

container.ondrop = (event) => {

	event.preventDefault()

  for (const file of event.dataTransfer.files) {

    if (!file.type.startsWith('image/')) continue

    image.src = URL.createObjectURL(file)

		setScale(1)
		saveImage(image)

  }

}

container.ondragover  = ((event) => event.preventDefault())

let scale = 1

function setScale(_scale) {

	scale = _scale

	const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))

	const translateX = matrix.m41
	const translateY = matrix.m42

	const height = image.offsetHeight * scale
	const width = image.offsetWidth * scale

	const rangeY = Math.max(0, height - container.offsetHeight) / 2
	const rangeX = Math.max(0, width - container.offsetWidth) / 2

	image.style.transform = `matrix(${scale}, 0, 0, ${scale}, ${Math.max(Math.min(translateX, rangeX), -rangeX)}, ${Math.max(Math.min(translateY, rangeY), -rangeY)})`

}

function setTransform(translateX, translateY) {

	const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))

	image.style.transform = `matrix(${matrix.a}, 0, 0, ${matrix.d}, ${translateX}, ${translateY})`

}

// We need to check if our on click started with image dragging
window.addEventListener('mousemove', ({ movementX, movementY, buttons }) => {

	if (buttons != 1) return

	const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))

	const translateX = matrix.m41
	const translateY = matrix.m42

	const { height, width } = image.getBoundingClientRect()

	const rangeY = Math.max(0, height - container.offsetHeight) / 2
	const rangeX = Math.max(0, width - container.offsetWidth) / 2

	setTransform(Math.max(Math.min(translateX + movementX, rangeX), -rangeX), Math.max(Math.min(translateY + movementY, rangeY), -rangeY))

})

container.addEventListener('wheel', ({ deltaY }) => {

	scale += deltaY > 0 ? -(0.1 * scale) : (0.1 * scale)
	scale = Math.min(Math.max(scale, 1), 50)

	setScale(scale)

})

function rotateImage() {



}

function deleteImage() {

	if (images.length <= 1)
	{

		image.src = ''

		return

	}
	if (currentImage <= 0) {

		images.shift()
		loadImage(currentImage)

		return

	}

	images.splice(currentImage, 1)
	currentImage--

	loadImage(currentImage)

}

window.addEventListener('keydown', (event) => {

	console.log(currentImage)

	if (event.key == 'ArrowRight' && currentImage + 1 < images.length) {

		const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))
		images[currentImage] = { src: image.src, matrix }

		currentImage++

		loadImage(currentImage)

	}

	if (event.key == 'ArrowLeft' && currentImage > 0) {

		const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))
		images[currentImage] = { src: image.src, matrix }

		currentImage--

		loadImage(currentImage)

	}

})