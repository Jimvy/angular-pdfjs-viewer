app = angular.module 'pdfHighlights', []

app.factory 'pdfHighlights', [ () ->
	class pdfHighlights

		constructor: (options) ->
			@highlightsLayerDiv = options.highlights;
			@viewport = options.viewport
			@highlightElements = [];

		addHighlight: (left, top, width, height) ->
			rect = @viewport.convertToViewportRectangle([left, top, left + width, top + height]);
			rect = PDFJS.Util.normalizeRect(rect);
			element = document.createElement("div");
			element.style.left = Math.floor(rect[0]) + 'px';
			element.style.top = Math.floor(rect[1]) + 'px';
			element.style.width = Math.ceil(rect[2] - rect[0]) + 'px';
			element.style.height = Math.ceil(rect[3] - rect[1]) + 'px';
			@highlightElements.push(element);
			@highlightsLayerDiv.appendChild(element);
			element

		clearHighlights: () ->
				# for (var i = 0; i < this.highlightElements.length; i++) {
				#			this.highlightElements[i].remove();
				# }
				# this.highlightElements = [];
]
