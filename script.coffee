demoApp = angular.module 'pdfDemo', ['pdfViewerApp']

window.demoApp = demoApp

demoApp.controller 'pdfDemoCtrl', ['$scope',  ($scope) ->
	$scope.pdfs = [
		'example-pdfjs/content/0703198.pdf'
		'example-pdfjs/content/1410.6514.pdf'
		'example-pdfjs/content/1410.6515.pdf'
		'example-pdfjs/content/0703198-mixed.pdf'
		'example-pdfjs/content/AMS55.pdf'
		]
	$scope.scales = [
		1
		0.5
		2
		'w'
		'h'
	]
	$scope.pdfSrc = $scope.pdfs[1]
	$scope.pdfSrc2 = $scope.pdfs[1]
	$scope.pdfScale = 'w'
	$scope.pdfScale2 = 'h'
	$scope.pdfState = { hello : true}

	]

app = angular.module 'pdfViewerApp', []

window.app = app

app.controller 'pdfViewerController', ['$scope', '$q', 'PDF', '$element', ($scope, $q, PDF, $element) ->
	@load = () ->
		return unless $scope.pdfSrc # skip empty pdfsrc
		$scope.document = new PDF($scope.pdfSrc, {scale: 1})
		$scope.loaded = $q.all({
			pdfPageSize: $scope.document.getPdfPageSize()
			numPages: $scope.document.getNumPages()
			}).then (result) ->
				$scope.pdfPageSize = [
					result.pdfPageSize[0],
					result.pdfPageSize[1]
				]
				console.log 'resolved q.all, page size is', result
				$scope.numPages = result.numPages

	@setScale = (scale, containerHeight, containerWidth) ->
		$scope.loaded.then () ->
			console.log 'in setScale scale', scale, 'container h x w', containerHeight, containerWidth
			if scale == 'w'
				# TODO margin is 10px, make this dynamic
				$scope.numScale = (containerWidth - 15) / ($scope.pdfPageSize[1])
				console.log('new scale from width', $scope.numScale)
			else if scale == 'h'
				# TODO magic numbers for jquery ui layout
				$scope.numScale = (containerHeight) / ($scope.pdfPageSize[0])
				console.log('new scale from width', $scope.numScale)
			else
				$scope.numScale = scale
			console.log 'in setScale, numscale is', $scope.numScale
			$scope.document.setScale($scope.numScale)
			$scope.defaultCanvasSize = [
				$scope.numScale * $scope.pdfPageSize[0],
				$scope.numScale * $scope.pdfPageSize[1]
			]

	@redraw = (pagenum, pagepos) ->
		console.log 'in redraw'
		console.log 'reseting pages array for', $scope.numPages
		$scope.pages = ({
			pageNum: i
		} for i in [1 .. $scope.numPages])
		if pagenum
			$scope.pages[pagenum-1].current = true
			$scope.pages[pagenum-1].position = pagepos

	@zoomIn = () ->
		console.log 'zoom in'
		$scope.numScaleForce = $scope.numScale * 1.2

	@zoomOut = () ->
		console.log 'zoom out'
		$scope.numScaleForce = $scope.numScale / 1.2
]

app.directive 'pdfViewer', ['$q', '$timeout', ($q, $timeout) ->
	{
		controller: 'pdfViewerController'
		controllerAs: 'ctrl'
		scope: {
			pdfSrc: "@"
			pdfScale: '@'
			pdfState: '='
		}
		template: "<div class='pdfviewer-controls'><button ng-click='ctrl.zoomIn()'>Zoom In</button> <button ng-click='ctrl.zoomOut()'>Zoom Out</button></div> <canvas class='pdf-canvas-new' data-pdf-page ng-repeat='page in pages'></canvas>"
		link: (scope, element, attrs, ctrl) ->
			console.log 'in pdfViewer element is', element
			console.log 'attrs', attrs
			layoutReady = $q.defer();
			layoutReady.notify 'waiting for layout'
			layoutReady.promise.then () ->
				console.log 'layoutReady was resolved'

			# TODO can we combine this with scope.parentSize, need to finalize boxes
			updateContainer = () ->
				scope.containerSize = [
					element.parent().innerWidth()
					element.parent().innerHeight()
					element.parent().offset().top
			]

			scope.$on 'layout-ready', () ->
				console.log 'GOT LAYOUT READY EVENT'
				console.log 'calling refresh'
				ctrl.load()
				updateContainer()
				layoutReady.resolve 'hello'
				scope.parentSize = [
					element.parent().innerHeight(),
					element.parent().innerWidth()
				]
				scope.$apply()

			scope.$on 'layout-resize', () ->
				console.log 'GOT LAYOUT-RESIZE EVENT'
				scope.parentSize = [
					element.parent().innerHeight(),
					element.parent().innerWidth()
				]
				scope.$apply()

			element.parent().on 'scroll', () ->
				console.log 'scroll detected', scope.adjustingScroll
				updateContainer()
				scope.$apply()
				console.log 'pdfposition', element.parent().scrollTop()
				if scope.adjustingScroll
					scope.adjustingScroll = false
				else
					console.log 'from auto scroll'
					visiblePages = scope.pages.filter (page) ->
						#console.log 'page is', page, page.visible
						page.visible
					topPage = visiblePages[0]
					console.log 'top page is', topPage.pageNum, topPage.elemTop, topPage.elemBottom
					# if pagenum > 1 then need to offset by half margin
					span = topPage.elemBottom - topPage.elemTop + 10
					position = (-topPage.elemTop+10)/span
					console.log 'position', position, 'span', span
					scope.pdfState.currentPageNumber = topPage.pageNum
					scope.pdfState.currentPagePosition = position
				scope.$apply()

			scope.$watch 'pdfSrc', () ->
				console.log 'loading pdf'
				ctrl.load()
				console.log 'XXX setting scale in pdfSrc watch'
				layoutReady.promise.then () ->
					ctrl.setScale(scope.pdfScale, element.parent().innerHeight(), element.parent().width()).then () ->
						ctrl.redraw()

			scope.$watch 'pdfScale', (newVal, oldVal) ->
				return if newVal == oldVal # no need to set scale when initialising, done in pdfSrc
				console.log 'XXX calling Setscale in pdfScale watch'
				layoutReady.promise.then () ->
					ctrl.setScale(newVal, element.parent().innerHeight(), element.parent().width()).then () ->
						ctrl.redraw()

			scope.$watch 'numScaleForce', (newVal, oldVal) ->
				console.log 'got change in numscale watcher', newVal, oldVal
				return unless newVal?
				origpagenum = scope.pdfState.currentPageNumber
				origpagepos = scope.pdfState.currentPagePosition
				layoutReady.promise.then () ->
					ctrl.setScale(newVal, element.parent().innerHeight(), element.parent().width()).then () ->
						# this can cause a duplicate redraw because parent size
						# forces a change numScale
						ctrl.redraw(origpagenum, origpagepos)
						# $timeout () ->
						#		console.log 'now try to preserve position', origpagenum, origpagepos
						#		newpos = $(element).find(':nth-child(' + origpagenum + ')').offset().top
						#		$(element).parent().scrollTop(newpos)
						# , 0
			scope.$watch('parentSize', (newVal, oldVal) ->
				console.log 'XXX in parentSize watch', newVal, oldVal
				if newVal == oldVal
					console.log 'returning because old and new are the same'
					return
				return unless oldVal?
				console.log 'XXX calling setScale in parentSize watcher'
				layoutReady.promise.then () ->
					ctrl.setScale(scope.pdfScale, element.parent().innerHeight(), element.parent().width()).then () ->
						ctrl.redraw()
			, true)

			# scope.$watch 'redraw', (newVal, oldVal) ->
			#		console.log 'got change in redraw watcher', newVal, oldVal
			#		return unless newVal
			#		ctrl.redraw()

			scope.$watch 'elementWidth', (newVal, oldVal) ->
				console.log '*** watch INTERVAL element width is', newVal, oldVal
	}
]

app.directive 'pdfPage', ['$timeout', ($timeout) ->
	{
		require: '^pdfViewer',
		link: (scope, element, attrs, ctrl) ->
			# TODO: do we need to destroy the watch or is it done automatically?
			#console.log 'in pdfPage link', scope.page.pageNum, 'sized', scope.page.sized, 'defaultCanvasSize', scope.defaultCanvasSize
			updateCanvasSize = (size) ->
				canvas = element[0]
				dpr = window.devicePixelRatio
				[canvas.height, canvas.width] = [Math.floor(dpr*size[0]), Math.floor(dpr*size[1])]
				element.height(Math.floor(size[0]))
				element.width(Math.floor(size[1]))
				element.removeClass('pdf-canvas-new')
				##console.log 'updating Canvas Size to', '[', size[0], size[1], ']'
				scope.page.sized = true

			isVisible = (containerSize) ->
				elemTop = element.offset().top - containerSize[2]
				elemBottom = elemTop + element.innerHeight()
				visible = (elemTop < containerSize[1] and elemBottom > 0)
				scope.page.visible = visible
				scope.page.elemTop = elemTop
				scope.page.elemBottom = elemBottom
				#console.log 'checking visibility', scope.page.pageNum, elemTop, elemBottom, scrollWindow[0], scrollWindow[1], visible
				return visible

			renderPage = () ->
				scope.page.rendered = true
				scope.document.renderPage element, scope.page.pageNum

			if (!scope.page.sized && scope.defaultCanvasSize)
				console.log('setting canvas size in directive', scope.defaultCanvasSize, scope.page.pageNum)
				updateCanvasSize scope.defaultCanvasSize

			if scope.page.current
				console.log 'we must scroll to this page', scope.page.pageNum,
					'at position', scope.page.position
				$timeout () ->
					newpos = $(element).offset().top - $(element).parent().offset().top
					console.log('top of page scroll is', newpos)
					#newpos = newpos + scope.page.position * $(element).innerHeight() + 10 + 5
					console.log('inner height is', $(element).innerHeight())
					offset = scope.page.position * ($(element).innerHeight() + 10)
					console.log('addition offset =', offset, 'total', newpos+offset)
					scope.$parent.adjustingScroll = true
					$(element).parent().parent().scrollTop(newpos+offset)
				renderPage()


			scope.$watch 'defaultCanvasSize', (defaultCanvaSize) ->
				#console.log 'in CanvasSize watch', 'scope.scrollWindow', scope.$parent.scrollWindow, 'defaultCanvasSize', scope.$parent.defaultCanvasSize, 'scale', scope.$parent.pdfScale
				return unless defaultCanvasSize?
				return if (scope.page.rendered or scope.page.sized)
				console.log('setting canvas size in watch', scope.defaultCanvasSize, 'with Scale', scope.pdfScale)
				updateCanvasSize defaultCanvasSize

			watchHandle = scope.$watch 'containerSize', (containerSize, oldVal) ->
				#console.log 'in scrollWindow watch', 'scope.scrollWindow', scope.$parent.scrollWindow, 'defaultCanvasSize', scope.$parent.defaultCanvasSize, 'scale', scope.$parent.pdfScale
				return unless containerSize?
				#console.log 'scrolling', scope.page.pageNum, 'page', scope.page, 'scrollWindow', scrollWindow, 'oldVal', oldVal
				return unless scope.page.sized
				return unless isVisible containerSize
				return if scope.page.rendered
				console.log 'in watch for containerSize', containerSize, oldVal
				console.log 'scope.page.rendered', scope.page.rendered
				renderPage()
				#watchHandle() # deregister this listener after the page is rendered
	}
]

app.factory 'PDF', ['$q', ($q) ->
	PDFJS.disableAutoFetch = true
	class PDF
		constructor: (@url, @options) ->
			@scale = @options.scale || 1
			@document = $q.when(PDFJS.getDocument @url)

		getNumPages: () ->
			@document.then (pdfDocument) ->
				pdfDocument.numPages

		getPdfPageSize: () ->
			@document.then (pdfDocument) =>
				pdfDocument.getPage(1).then (page) =>
					viewport = page.getViewport 1
					[viewport.height, viewport.width]

		getScale: () ->
			@scale

		setScale: (@scale) ->
			console.log 'in setScale of renderer', @scale

		renderPage: (canvas, pagenum) ->
			scale = @scale
			@document.then (pdfDocument) ->
				pdfDocument.getPage(pagenum).then (page) ->
					console.log 'rendering at scale', scale, 'pagenum', pagenum
					dpr = window.devicePixelRatio
					viewport = page.getViewport dpr*scale
					console.log 'devPixRatio size', devicePixelRatio*viewport.height, devicePixelRatio*viewport.width
					[canvas[0].height, canvas[0].width] = [viewport.height, viewport.width]
					console.log Math.round(viewport.height) + 'px', Math.round(viewport.width) + 'px'
					canvas.height(Math.floor(viewport.height/dpr) + 'px')
					canvas.width(Math.floor(viewport.width/dpr) + 'px')
					context = canvas[0].getContext '2d'
					backingStoreRatio = context.webkitBackingStorePixelRatio ||
						context.mozBackingStorePixelRatio ||
						context.msBackingStorePixelRatio ||
						context.oBackingStorePixelRatio ||
						context.backingStorePixelRatio || 1
					console.log 'backingStoreRatio', backingStoreRatio
					page.render {
						canvasContext: context
						viewport: viewport
						}
	]
