const container = document.getElementById('root')
const image = document.getElementById('image')

let scale = 1

function setScale(scale) {

	const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))

	const translateX = matrix.m41
	const translateY = matrix.m42

	image.style.transform = `matrix(${scale}, 0, 0, ${scale}, ${translateX}, ${translateY})`

}

function setTransform(translateX, translateY) {

	const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))
	const scale = matrix.a

	image.style.transform = `matrix(${scale}, 0, 0, ${scale}, ${translateX}, ${translateY})`

}

container.addEventListener('mousemove', ({ movementX, movementY, buttons }) => {

	if (buttons != 1) return

	const matrix = new DOMMatrix(image.style.getPropertyValue('transform'))

	const translateX = matrix.m41
	const translateY = matrix.m42

	setTransform(translateX + movementX, translateY + movementY)

})

container.addEventListener('wheel', ({ deltaY }) => {

	scale += deltaY > 0 ? -(0.1 * scale) : (0.1 * scale)
	scale = Math.min(Math.max(scale, 1), 50)

	setScale(scale)

})