body = document.querySelector 'body'

tools =
  insert: (file) ->
    head = document.querySelector 'head'

    if file.type is 'css'
      style = document.createElement 'link'
      src = document.createAttribute 'href'
      type = document.createAttribute 'type'
      rel = document.createAttribute 'rel'
      src.value = file.src
      type.value = 'text/css'
      rel.value = 'stylesheet'
      style.setAttributeNode src
      style.setAttributeNode type
      style.setAttributeNode rel
      head.appendChild style

    else if file.type is 'script'
      js = document.createElement 'script'
      src = document.createAttribute 'src'
      src.value = file.src
      js.setAttributeNode src
      body.appendChild js

files = [
  {
    type: 'css'
    src: '//stg-sprocket-gears.s3.amazonaws.com/navigation/css/navigation.css'
  }
  {
    type: 'css'
    #src: '//stg-sprocket-assets.s3.amazonaws.com/bookmarklets/css/navigation-step-editor.css?t=' + new Date().getTime()
    src: '//localhost:8888/navigation-step-editor.css?t=' + new Date().getTime()
  }
  {
    type: 'script'
    src: '//cdnjs.cloudflare.com/ajax/libs/zeroclipboard/2.2.0/ZeroClipboard.min.js'
  }
]

config =
  bodyClass: '_XPATH_BODY'
  appendId: '_XPATH_APPEND_WRAPPER'

if not window.Vue
  files.push
    type: 'script'
    src: '//cdnjs.cloudflare.com/ajax/libs/vue/1.0.15/vue.min.js'

for file in files
  tools.insert file

window._XPATH_INIT = true

$addClass = (ele, className) ->
  originClass = ele.className
  if originClass.indexOf(className) is -1
    ele.className += " #{className}"

$removeClass = (ele, className) ->
  originClass = ele.className
  if originClass.indexOf(className) isnt -1
    ele.className = originClass.replace className, ''

$create = (ele) ->
  document.createElement ele

$extend = (source, target) ->
  for key, value of target
    source[key] = value
  source

xpath = (el) ->
  if typeof el is "string"
    return document.evaluate el, document, null, 0, null
  if not el or el.nodeType isnt 1
    return ''
  if el.id and el.id.length isnt 42  # except chrome click id
    return "//*[@id='#{el.id}']"
  sames = [].filter.call el.parentNode.children, (x) ->
    return x.tagName is el.tagName
  t = ''
  if sames.length > 1
    t = '['+([].indexOf.call(sames, el) + 1 ) + ']'
  return xpath(el.parentNode) + '/' + el.tagName.toLowerCase() + t

getSize = (dom) ->
  style = dom.getBoundingClientRect()

  return {
    width: style.width
    height: style.height
    left: style.left + window.scrollX
    top: style.top + window.scrollY
  }

if not Application
  Application = ->
    this.version = '1.0'

app = new Application

app = $extend app,
  init: ->
    @insertWrapper()
    @toolbarRender()
    @maskRender()
    @modalRender()
    @stepRender()

  insertWrapper: ->
    body.className = body.className + ' ' + config.bodyClass
    toolbar = $create 'div'
    toolbar.id = config.appendId
    toolbar.innerHTML = [
      '<tool-bar></tool-bar>'
      '<mask-block></mask-block>'
      '<modal-layer></modal-layer>'
      '<step-layer></step-layer>'
    ].join ''
    body.appendChild toolbar
    this.parentVue = new Vue()
    this.options =
      el: "##{config.appendId}"
      parent: this.parentVue

  toolbarRender: ->
    template = [
      '<div id="_XPATH_TOOLBAR" class="xpath-start-hide">'
        '<textarea class="xpath-container" readOnly="true" v-model="selected.xpath"></textarea>'
        '<button class="xpath-start">Start</button>'
        '<button class="xpath-stop">Stop</button>'
        '<form class="xpath-setting">'
          '<div class="xpath-step-type">'
            '<p>表示タイプ</p>'
            '<label v-for="type in config.type" class="type-{{type}}">'
              '<input type="radio" name="type" value="{{type}}" v-model="selected.type">'
              '{{type}}'
            '</label>'
          '</div>'
          '<div class="xpath-step-modal" v-show="selected.type != \'toast\'">'
            '<p>モーダル</p>'
            '<label class="position-top"><input type="checkbox" name="modal" v-model="selected.noModal"> なし</label>'
          '</div>'
          '<div class="xpath-step-position" v-show="selected.type != \'dialog\'">'
            '<p>表示位置</p>'
            '<label v-for="position in config.position" class="position-{{position}}">'
              '<input type="radio" name="position" value="{{position}}" v-model="selected.position">'
              '{{position}}'
            '</label>'
          '</div>'
          '<div class="xpath-step-button" v-show="showButton()">'
            '<button type="button" class="xpath-preview" @click="preview()">Preview</button>'
            '<button type="button" class="xpath-clear" @click="clear()">Clear</button>'
            '<button type="button" class="xpath-save" @click="done()">決めた</button>'
          '</div>'
        '</form>'
      '</div>'
    ].join ''
    toolbarComponent = Vue.extend
      template: template
      ready: ->
        that = this;
        console.log 'toolbar ready'
        this.$on 'element-selected', (data) ->
          that.selected.xpath = data.xpath
          cl = document.evaluate(data.xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
          that.selected.dom = cl
          $addClass that.selected.dom, 'xpath-selected-dom'
      data: ->
        config:
          type: ['toast', 'balloon', 'dialog']
          position: ['top', 'bottom', 'left', 'right']
        selected:
          xpath: ''
          noModal: false
          type: 'toast'
          position: 'top'
        showButton: ->
          if not @selected.type or (@selected.type isnt 'dialog' and not @selected.position)
            return false
          else
            return true
        preview: ->
          app.parentVue.$broadcast 'preview-action', @selected
        clear: ->
          app.parentVue.$broadcast 'clear-action'
        done: ->
          app.parentVue.$broadcast 'done-action', @selected

    Vue.component 'tool-bar', toolbarComponent
    this.toolbar = new Vue this.options

  maskRender: ->
    template = '<div :style="styles"></div>'
    maskComponent = Vue.extend
      template: template
      ready: ->
        that = this;
        console.log 'mask ready'
        ele = body.querySelectorAll('*')
        wrapper = document.querySelector "##{config.appendId}"
        body.addEventListener 'mouseenter', (event) ->
          target = event.target
          if wrapper.contains target or not window._XPATH_STATUS
            return
          event.stopPropagation()
          options = getSize target
          options.height += 4
          options.width += 4
          that.styles.opacity = 1
          for key, value of options
            that.styles[key] = value + 'px'
        , true

        body.addEventListener 'mouseout', (event) ->
          target = event.target
          that.styles.opacity = 0
          event.stopPropagation()
          if wrapper.contains target or not window._XPATH_STATUS
            return
        , true

        body.addEventListener 'click', (event) ->
          target = event.target
          if wrapper.contains target or not window._XPATH_STATUS
            return
          event.stopPropagation()
          p = xpath target
          app.parentVue.$broadcast 'element-selected',
            xpath: p
        , true
      data: ->
        styles:
          position: 'absolute'
          'z-index': 100000
          'border-radius': '4px'
          'box-shadow': '0 0 10px rgba(0,0,0,.8)'
          opacity: 1
          'pointer-events': 'none'
          transform: 'translate(-2px, -2px)'
          transition: 'all .15s ease-in-out'

    Vue.component 'mask-block', maskComponent
    this.mask = new Vue this.options

  modalRender: ->
    template = [
      '<div class="spm-navigation-overlay" style="opacity: 0.6" v-show="modal"></div>'
    ].join ''
    modalComponent = Vue.extend
      template: template,
      ready: ->
        that = this
        this.$on 'preview-action', (selected) ->
          that.modal = not selected.noModal and selected.type isnt 'toast'
        this.$on 'clear-action', ->
          that.modal = false
      data: ->
        modal: false

    Vue.component 'modal-layer', modalComponent
    this.modal = new Vue this.options

  stepRender: (type) ->
    template = [
      '<div v-el:container :style="styles.step" class="spm-{{selected.type}} {{selected.position}} spg-navigation {{animation}}">'
        '<button type="button" class="spm-{{selected.type}}-close" @click="destroy()"></button>'
        '<div class="spm-balloon-arrow" v-if="selected.type === \'balloon\'"></div>'
        '<h3 class="spm-{{selected.type}}-title" contenteditable="true" v-el:title>{{title}}</h3>'
        '<div class="spm-{{selected.type}}-content" contenteditable="true" v-el:content>{{* content}}</div>'
        '<div class="xpath-position-update spm-balloon-button" v-show="isUpdated()">Update</div>'
        '<div class="spm-{{selected.type}}-nav">'
          '<div class="spm-{{selected.type}}-button">{{button}}</div>'
        '</div>'
      '</div>'
      '<div v-el:light v-show="selected.type === \'balloon\'" :style="styles.light" class="spm-navigation-navlayer"></div>'
    ].join ''

    stepComponent = Vue.extend
      template: template
      ready: ->
        that = this
        window.styles = this.styles
        this.$on 'preview-action', (selected) ->
          that.render selected
        this.$on 'clear-action', ->
          that.selected.type = ''
        this.$els.title.addEventListener 'DOMSubtreeModified', (event) ->
          that.setSize()
        , false

        this.$els.content.addEventListener 'DOMSubtreeModified', (event) ->
          that.setSize()
        , false
      data: ->
        selected:
          type: ''
          position: 'top'
        styles:
          step:
            left: 0
            top: 0
          light:
            left: 0
            top: 0
        title: 'KPIのページ'
        content: 'ページを跨ぎます。ページを跨ぎます。'
        button: '次へ'
        animation: 'fade in'
        setSize: (settings) ->
          @size = settings if settings
          @size = getSize @$els.container
        setStyle: (type) ->
          if @selected isnt 'balloon'
            false
          else
            @selected.styles[type]

        render: (selected) ->
          that = this
          @selected = $extend {}, selected
          setTimeout ->
            that.styles.step =
              transition: 'all 0.2s ease-in-out'
            if that.selected.type is 'balloon'
              delta = 20
              selectElement = document.evaluate(that.selected.xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
              selectElement.className = selectElement.className + 'spm-navigation-float spm-navigation-relative'
              selectSize = getSize selectElement
              that.setSize()
              X = selectSize.left
              Y = selectSize.top
              H = selectSize.height
              W = selectSize.width
              h = that.size.height
              w = that.size.width

              switch that.selected.position
                when 'top'
                  x = X + (W - w) / 2
                  y = Y - delta - h
                when 'bottom'
                  x = X + (W - w) / 2
                  y = Y + H + delta
                when 'left'
                  x = X - delta - w
                  y = Y + (H - h) / 2
                when 'right'
                  x = X + delta + W
                  y = Y + (H - h) / 2
                else
              that.styles.step = $extend that.styles.step,
                left: x + 'px'
                top: y + 'px'
                display: 'block'

              border = 4
              that.styles.light = $extend that.styles.light,
                top: Y - border + 'px'
                left: X - border + 'px'
                width: W + 2 * border + 'px'
                height: H + 2 * border + 'px'

            else if that.selected.type is 'dialog'
              that.selected.position = ''
            else if that.selected.type is 'toast'
              style = window.getComputedStyle(that.$els.container)
              selectSize = getSize that.$els.container
              width = selectSize.width -
              parseInt(style.paddingLeft, 10) -
              parseInt(style.paddingRight, 10) -
              parseInt(style.borderTopWidth, 10) -
              parseInt(style.borderBottomWidth, 10)
              if style.maxWidth is '100%'
                width -= 200
              that.styles.step.width = width + 'px'
              that.styles.step.maxWidth = width + 'px'
          , 0

        destroy: ->
          app.parentVue.$broadcast 'clear-action'

    Vue.component 'step-layer', stepComponent

    Vue.directive 'element',
      twoWay: true
      bind: ->
        that = this
        #that.size = getSize that.el
        this.el.addEventListener 'DOMSubtreeModified', (event) ->
          size = getSize that.el
          that.set size
        , false
      update: (newVal, oldVal) ->
        that = this
        console.log newVal, oldVal, this.size

    this.step = new Vue this.options

  doneRender: ->
    template = [].join ''
    doneComponent = Vue.extend
      template: template
      ready: ->
        this.$on 'done-action', (selected) ->
      data: ->

    Vue.component 'done-layer', doneComponent
    this.done = new Vue this.options

timer = setInterval ->
  if window.Vue
    clearInterval timer
    app.init()
, 200
