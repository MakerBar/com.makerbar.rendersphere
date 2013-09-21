package com.makerbar.x2

import java.awt.event.KeyEvent
import java.io.File
import java.io.FileReader
import java.util.HashMap
import java.util.Properties
import javax.swing.JFileChooser
import javax.swing.JOptionPane
import javax.swing.filechooser.FileNameExtensionFilter
import processing.core.PApplet
import processing.core.PGraphics
import processing.core.PImage
import processing.video.Capture
import processing.video.Movie

import static java.awt.event.KeyEvent.*
import static javax.swing.JFileChooser.*
import gifAnimation.Gif
import com.makerbar.x2.client.X2Client

class POVConsole extends PApplet {

	static val WIDTH = 4 * 56
	static val HEIGHT = 6 * 17
	
	static val X2_HOST = "192.168.0.3"

	def static void main(String[] args) {
		PApplet::main("com.makerbar.x2.POVConsole")
	}
	
	//
	
	PImage image
	Gif gif
	Movie movie
	Capture camera
	String selectedCamera
	
	PGraphics pg
	PGraphics imgPG
	
	int imageWidth
	int imageHeight
	float imageScaleFactor = 1
	int imageXOffset
	int imageYOffset
	
	int globeXOffset
	int globeYOffset
	
	long then = System::currentTimeMillis / 33
	int rotationSpeed
	int rotationDirection = 1
	boolean flipImage = false
	
	float brightness = 0
	float contrast = 1
	
	var boolean dirty
	
	double rps  // rotations per second
	long fps  // frames per second
	
	override setup() {
		size(700, 400)
		
		pg = createGraphics(WIDTH, HEIGHT)
		imgPG = createGraphics(WIDTH, HEIGHT)
		
		loadProperties
	}
	
	override draw() {
		val now = System::currentTimeMillis / 33
		if (now > then) {
			setGlobeXOffset(globeXOffset + (rotationSpeed * rotationDirection))
			then = now
		}
		
		if (camera != null && camera.available) {
			camera.read
			dirty = true
		}
		
		// Clear
		background(100)
		
		pushMatrix
		translate(40, 80)
		
		drawImage
		
		// Draw frame
		pushStyle
		stroke(200)
		noFill
		rect(-1, -1, WIDTH + 1, HEIGHT + 1)
		popStyle
		
		popMatrix

		text('''Display dimensions: «WIDTH» x «HEIGHT»''', 40, 80 - 20 - textDescent)
		
		displayText
		
//		val stats =
//			if (dirty) {
//				dirty = false
//				X2Client::sendData(X2_HOST, pg.pixels)
//			} else {
//				X2Client::getStats(X2_HOST)
//			}
//		rps = stats.get(0) as Double
//		fps = stats.get(1) as Long
		
		translate(40, 80 + HEIGHT + 20)
		text(String::format("%1.2f RPM", rps * 60), 0, textAscent)
		translate(0, 20)
		text('''«fps» FPS''', 0, textAscent)
	}
	
	def drawImage() {
		// Draw image on pg
		pg.beginDraw
		pg.background(0)
		
		// Tile globe image
		if (image != null) {
			// Apply brightness & contrast
			val xImg = new PImage(image.width, image.height)
			image.loadPixels
			for (i : 0 ..< image.width * image.height) {
				val inColor = image.pixels.get(i)
				var r = (inColor >> 16).bitwiseAnd(0xFF)
       			var g = (inColor >> 8).bitwiseAnd(0xFF)
       			var b = inColor.bitwiseAnd(0xFF)

				// apply contrast (multiplication) and brightness (addition)
				r = (r * contrast + brightness) as int
				g = (g * contrast + brightness) as int
				b = (b * contrast + brightness) as int
   
				r = if (r < 0) 0 else if (r > 255) 255 else r
				g = if (g < 0) 0 else if (g > 255) 255 else g
				b = if (b < 0) 0 else if (b > 255) 255 else b
   
				xImg.pixels.set(i, 0xff000000.bitwiseOr(r << 16).bitwiseOr(g << 8).bitwiseOr(b))
			}
			xImg.updatePixels
			
			// Draw globe
			if (flipImage) {
				pg.scale(-1, 1)
				pg.translate(-(WIDTH - 1), 0)
			}
			
			val minX = if (globeXOffset > 0) globeXOffset - WIDTH else globeXOffset
			val minY = if (globeYOffset > 0) globeYOffset - HEIGHT else globeYOffset
			
			var x = minX
			while (x < WIDTH) {
				var y = minY
				while (y < HEIGHT) {
					pg.pushMatrix
					pg.translate(x, y)
					
					imgPG.beginDraw
					imgPG.background(0)
					imgPG.translate(imageXOffset, imageYOffset)
					imgPG.scale(imageScaleFactor)
					imgPG.image(xImg, 0, 0)
					imgPG.endDraw
					
					pg.image(imgPG, 0, 0)
					pg.popMatrix
					
					y = y + HEIGHT
				}
				
				x = x + WIDTH
			}
		}
		
		pg.endDraw
		
		// Draw pg to screen
		image(pg, 0, 0)
	}
	
	def void movieEvent(Movie m) {
		m.read
		dirty = true
	}
	
	def displayText() {
		pushMatrix
		pushStyle
		
		translate(400, 20)
		
		stroke(255)
		text('''
			l : re/load properties
			o : open image file
			c : capture video
			
			«IF image != null»
				-/+ : scale image decrease/increase
				H/K/U/J : image offset left/right/up/down
				arrow keys : globe offset
				A/D : contrast decrease/increase
				S/W : brightness decrease/increase
				(hold shift for fine scale/offset)
				0-9 : rotation speed
				R : change rotation direction
				F : flip image
			«ENDIF»
			
			«IF imageScaleFactor != 1»scale factor: «imageScaleFactor»«ENDIF»
			«IF imageXOffset != 0»image x offset: «imageXOffset»«ENDIF»
			«IF imageYOffset != 0»image y offset: «imageYOffset»«ENDIF»
			«IF flipImage»flipped«ENDIF»
			«IF brightness != 0»brightness: «brightness»«ENDIF»
			«IF contrast != 1»contrast: «contrast»«ENDIF»
			«IF rotationSpeed > 0»rotation speed: «rotationSpeed»«ENDIF»
			«IF globeXOffset != 0»globe x offset: «globeXOffset»«ENDIF»
			«IF globeYOffset != 0»globe y offset: «globeYOffset»«ENDIF»
			''', 0, 0)
		
		popStyle
		popMatrix
	}
	
	override keyPressed(KeyEvent event) {
		if (image == null) {
			switch (event.keyCode) {
				case VK_O: openImageFile
				case VK_C: captureVideo
			}
		} else {
			val factor = if (event.shiftDown) 1 else 10
			switch (event.keyCode) {
				case VK_L: loadProperties
				
				case VK_O: openImageFile
				case VK_C: captureVideo
				
				case VK_EQUALS: setImageScaleFactor(imageScaleFactor + 0.01f * factor)
				case VK_MINUS: setImageScaleFactor(imageScaleFactor - 0.01f * factor)
				
				case VK_H: imageXOffset = imageXOffset - 1 * factor
				case VK_K: imageXOffset = imageXOffset + 1 * factor
				case VK_U: imageYOffset = imageYOffset - 1 * factor
				case VK_J: imageYOffset = imageYOffset + 1 * factor
				
				case VK_LEFT: setGlobeXOffset(globeXOffset - 1 * factor)
				case VK_RIGHT: setGlobeXOffset(globeXOffset + 1 * factor)
				case VK_UP: setGlobeYOffset(globeYOffset - 1 * factor)
				case VK_DOWN: setGlobeYOffset(globeYOffset + 1 * factor)
				
				case VK_0: setRotationSpeed(0)
				case VK_1: setRotationSpeed(1)
				case VK_2: setRotationSpeed(2)
				case VK_3: setRotationSpeed(3)
				case VK_4: setRotationSpeed(4)
				case VK_5: setRotationSpeed(5)
				case VK_6: setRotationSpeed(6)
				case VK_7: setRotationSpeed(7)
				case VK_8: setRotationSpeed(8)
				case VK_9: setRotationSpeed(9)
				case VK_R: toggleRotationDirection
				
				case VK_F: toggleFlipImage
				
				case VK_S: setBrightness(brightness - 1 * factor)
				case VK_W: setBrightness(brightness + 1 * factor)
				
				case VK_A: setContrast(contrast - 1 * factor)
				case VK_D: setContrast(contrast + 1 * factor)
				
				case VK_ESCAPE: resetSettings
			}
			
			dirty = true
		}
	}
	
	def setImageScaleFactor(float scaleFactor) {
		this.imageScaleFactor = scaleFactor
	}
	
	def setGlobeXOffset(int xOffset) {
		globeXOffset = xOffset % WIDTH
		if (globeXOffset < 0) globeXOffset = globeXOffset + WIDTH
	}
	
	def setGlobeYOffset(int yOffset) {
		globeYOffset = yOffset % HEIGHT
		if (globeYOffset < 0) globeYOffset = globeYOffset + HEIGHT
	}
	
	def setRotationSpeed(int rotationSpeed) {
		this.rotationSpeed = rotationSpeed
	}
	
	def toggleRotationDirection() {
		rotationDirection = if (rotationDirection == 1) -1 else 1
	}
	
	def toggleFlipImage() {
		flipImage = !flipImage
		rotationDirection = if (rotationDirection == 1) -1 else 1
	}
	
	def setBrightness(float brightness) {
		this.brightness = brightness
	}
	
	def setContrast(float contrast) {
		this.contrast = if (contrast <= 0) 1 else contrast
	}
	
	def resetSettings() {
		if (movie != null) {
			movie.stop
			movie = null
		}
		if (gif != null) {
			gif.stop
			gif = null
		}
		if (camera != null) {
			camera.stop
			camera = null
		}
		
		imageScaleFactor = 1
		imageXOffset = 0
		imageYOffset = 0
		
		rotationSpeed = 0
		rotationDirection = 1
		flipImage = false
		
		brightness = 0
		contrast = 1
		
		globeXOffset = 0
		globeYOffset = 0
	}
	
	def loadProperties() {
		val properties = new Properties
		val file = new File("pov-console.properties")
		// Load properties file if it exists
		if (file.exists) {
			val reader = new FileReader(file)
			properties.load(reader)
			reader.close
			
			val frameRateProperty = properties.getProperty("frameRate")
			if (frameRateProperty != null) frameRate(Float::valueOf(frameRateProperty))
			
			val imageFileProperty = properties.getProperty("imageFile")
			if (imageFileProperty != null) imageFileProperty.openImage
			
			selectedCamera = properties.getProperty("camera")
			
			val scaleFactorProperty = properties.getProperty("scaleFactor")
			if (scaleFactorProperty != null) setImageScaleFactor(Float::parseFloat(scaleFactorProperty))
			
			val imageXOffsetProperty = properties.getProperty("imageXOffset")
			if (imageXOffsetProperty != null) imageXOffset = Integer::parseInt(imageXOffsetProperty)
			
			val imageYOffsetProperty = properties.getProperty("imageYOffset")
			if (imageYOffsetProperty != null) imageYOffset = Integer::parseInt(imageYOffsetProperty)
			
			val rotationSpeedProperty = properties.getProperty("rotationSpeed")
			if (rotationSpeedProperty != null) setRotationSpeed(Integer::parseInt(rotationSpeedProperty))
			
			val rotationDirectionProperty = properties.getProperty("rotationDirection")
			if (rotationDirectionProperty != null) rotationDirection = Integer::parseInt(rotationDirectionProperty)
			
			val flipImageProperty = properties.getProperty("flipImage")
			if (flipImageProperty != null) flipImage = Boolean::parseBoolean(flipImageProperty)
			
			val brightnessProperty = properties.getProperty("brightness")
			if (brightnessProperty != null) brightness = Float::parseFloat(brightnessProperty)
			
			val contrastProperty = properties.getProperty("contrast")
			if (contrastProperty != null) contrast = Float::parseFloat(contrastProperty)
			
			val globeXOffsetProperty = properties.getProperty("globeXOffset")
			if (globeXOffsetProperty != null) setGlobeXOffset(Integer::parseInt(globeXOffsetProperty))
			
			val globeYOffsetProperty = properties.getProperty("globeYOffset")
			if (globeYOffsetProperty != null) setGlobeYOffset(Integer::parseInt(globeYOffsetProperty))
		}
	}
	
	val imageFileFilter = new FileNameExtensionFilter("Image/Movie file (png, jpg, bmp, gif, mov)", #{ "png", "jpg", "bmp", "gif", "mov" })
	val fileChooser = new JFileChooser(new File("images")) => [
		acceptAllFileFilterUsed = false
		addChoosableFileFilter = imageFileFilter
		fileFilter = imageFileFilter
	]
	
	def void openImageFile() {
		resetSettings
		
		if (fileChooser.showOpenDialog(this) == APPROVE_OPTION) {
			val selectedFile = fileChooser.selectedFile
			selectedFile.canonicalPath.openImage
		}
	}
	
	def void openImage(String filePath) {
		if (filePath.toLowerCase.endsWith(".gif")) {
			println('''GIF Image file: «filePath»''')
			gif = setImage(new Gif(this, filePath))
			gif.loop
		} else if (filePath.toLowerCase.endsWith(".mov")) {
			println('''Movie file: «filePath»''')
			movie = setImage(new Movie(this, filePath))
			movie.loop
		} else {
			println('''Image file: «filePath»''')
			setImage(loadImage(filePath))
		}
	}
	
	def void captureVideo() {
		resetSettings
		
		if (selectedCamera == null) {
			cursor(WAIT)
			val cameras = Capture::list
			cursor(ARROW)
			selectedCamera = JOptionPane::showInputDialog(this, "", "Select camera", JOptionPane::PLAIN_MESSAGE, null, cameras, null) as String
		}
		
		if (selectedCamera != null) {
			println('''Opening camera «selectedCamera»''')
			
			val cameraProperties = new HashMap<String, String>
			for (p : selectedCamera.split(",")) {
				val kv = p.split("=")
				cameraProperties.put(kv.get(0), kv.get(1))
			}
			
			val size = cameraProperties.get("size")
			val wh = size.split("x")
			imageWidth = Integer::valueOf(wh.get(0))
			imageHeight = Integer::valueOf(wh.get(1))
			
			camera = setImage(new Capture(this, selectedCamera))
			
			camera.start
		}
	}
	
	def <T extends PImage> setImage(T img) {
		resetSettings
		
		image = img
		dirty = true
		
		if (image.width > 0) imageWidth = image.width
		if (image.height > 0) imageHeight = image.height
		
		autoscale
		
		img
	}
	
	def autoscale() {
		if (((imageWidth as float) / imageHeight) < ((WIDTH as float) / HEIGHT)) {
			imageScaleFactor = (HEIGHT as float) / imageHeight
			imageXOffset = ((WIDTH - (imageWidth * imageScaleFactor)) / 2) as int
		} else {
			imageScaleFactor = (WIDTH as float) / imageWidth
			imageYOffset = ((HEIGHT - (imageHeight * imageScaleFactor)) / 2) as int
		}
	}
	
}
