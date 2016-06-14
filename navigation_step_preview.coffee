body = document.querySelector 'body'

env =
  stg:
    api: 'api-stg.sb.v2.sprocket.bz'
    config: 'api-admin-stg.sb.v2.sprocket.bz/dev'
    asset: 'stg-sprocket-assets.s3.amazonaws.com'
  sb:
    api: 'api.sb.v2.sprocket.bz'
    config: 'api-admin.sb.v2.sprocket.bz/dev'
    asset: 'sb-sprocket-assets.s3.amazonaws.com'
  pd:
    api: 'api.v2.sprocket.bz'
    config: 'api-admin.v2.sprocket.bz/prod'
    asset: 'sprocket-assets.s3.amazonaws.com'


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
    src: '//stg-sprocket-assets.s3.amazonaws.com/bookmarklets/css/navigation-step-editor.css?t=' + new Date().getTime()
  }
  # {
  #   type: 'script'
  #   src: '//cdnjs.cloudflare.com/ajax/libs/zeroclipboard/2.2.0/ZeroClipboard.min.js'
  # }
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
    ele.className += " #{className} "

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

$get = (url, callback) ->
  xhr = new XMLHttpRequest()
  xhr.open 'GET', url
  xhr.send null
  xhr.onreadystatechange = ->
    DONE = 4
    OK = 200
    if xhr.readyState is DONE and xhr.status is OK
      response = JSON.parse xhr.responseText
      callback callback(response)

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

cpath = (el) ->
  names = []
  while el.parentNode
    if el.id
      names.unshift '#' + el.id
      break
    else
      if el == el.ownerDocument.documentElement
        names.unshift el.tagName.toLowerCase()
      else
        c = 1
        e = el
        while e.previousElementSibling
          e = e.previousElementSibling
          c++
        names.unshift el.tagName.toLowerCase() + ':nth-child(' + c + ')'
      el = el.parentNode
  names.join ' > '


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

  insertWrapper: ->
    body.className = body.className + ' ' + config.bodyClass
    toolbar = $create 'div'
    toolbar.id = config.appendId
    toolbar.innerHTML = [
      '<tool-bar></tool-bar>'
      '<done-layer></done-layer>'
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
        '<div class="dev-choose">'
          '<span v-show="selected.dev === \'stg\'">STG</span>'
          '<span v-show="selected.dev === \'sb\'">SB</span>'
        '</div>'
        '<strong>Sprocketタグを入力してください</strong>'
        '<textarea class="xpath-container" v-model="selected.resourcePath" v-on:keyup="pathChaned()"></textarea>'
        '<button class="xpath-init" @click="formatData()">Init</button>'
        '<button type="button" class="xpath-clear" @click="clear()">Reset</button>'
        '<div class="xpath-setting" style="display: none;">'
          '<div class="xpath-step-type">'
            '<p>表示タイプ</p>'
            '<label v-for="type in config.type" class="type-{{type}}">'
              '<input type="radio" name="type" value="{{type}}" v-model="selected.type">'
              ' {{type}}'
            '</label>'
          '</div>'
          '<div class="xpath-step-modal" v-show="selected.type != \'toast\'">'
            '<p>モーダル</p>'
            '<label class="position-top"><input type="checkbox" name="modal" v-model="selected.useModal"> あり</label>'
          '</div>'
          '<div class="xpath-step-position" v-show="selected.type != \'dialog\'">'
            '<p>表示位置</p>'
            '<label v-for="position in config.position" class="position-{{position}}">'
              '<input type="radio" name="position" value="{{position}}" v-model="selected.position">'
              ' {{position}}'
            '</label>'
          '</div>'
          '<div class="xpath-step-button" v-show="showButton()">'
            '<button type="button" class="xpath-preview" @click="preview()">Preview</button>'
            '<button type="button" class="xpath-clear" @click="clear()">Reset</button>'
          '</div>'
        '</div>'
        '<div>'
          '<strong>CSSセレクト</strong>'
          '<textarea id="SP_copy_textarea" class="xpath-container" readOnly="true" v-model="selected.cpath"></textarea>'
        '</div>'
      '</div>'
    ].join ''
    toolbarComponent = Vue.extend
      template: template
      ready: ->
        that = this;
        console.log 'toolbar ready'
        this.$on 'element-selected', (data) ->
          that.selected.xpath = data.xpath
          that.selected.cpath = data.cpath
          cl = document.evaluate(data.xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
          cd = document.querySelector data.cpath
          that.selected.dom = cd
          $addClass that.selected.dom, 'xpath-selected-dom'

        #this.initCopy()

      data: ->
        reg: /^service\(([^\(]+)\)-key\(([^\(]+)\)-\((scenario[0-9]+)\)-\((phase[0-9]+)\)-\((pattern[0-9]+)\)-\((.+)\)-style\((.+)\)-class\((.+)\)$/
        config:
          type: ['toast', 'balloon', 'dialog']
          placement: ['top', 'bottom', 'left', 'right']
        selected:
          dev: ''
          resourcePath: ''
          ids: {}
          formatStatus: false
          cpath: ''
          xpath: ''
          useModal: true
          type: 'toast'
          placement: 'top'
        initCopy: ->
          that = this
          copyBtn = @$els.copy
          client = new ZeroClipboard copyBtn
          client.on 'ready', ->
            client.on 'aftercopy', ->
              alert 'copy success'
              that.selected.copyStatus = true
        showButton: ->
          if not @selected.type or (@selected.type isnt 'dialog' and not @selected.placement)
            return false
          else
            return true

        pathChaned: ->
          that = this
          console.log ('change')
          path = that.selected.resourcePath
          that.formatData() if path and path.match that.reg

        loadStylesheet: ->
          that = this
          stylesheetUrl = type: 'css'
          stylesheet = that.selected.ids.stylesheet
          stylesheet = stylesheet.replace(/^(http:|https:|ftp:)/, '').replace(/\/\//, '')
          dev = stylesheet.split('-')[0]
          stylesheetUrl.src = '//' + stylesheet
          that.selected.dev = if dev is 'stg' or dev is 'sb' then dev else 'pd'
          tools.insert stylesheetUrl

        formatData: ->
          that = this
          path = @selected.resourcePath
          result = []
          path = path.replace @reg, (matched, $1, $2, $3, $4, $5, $6, $7, $8) ->
            that.selected.ids =
              service: $1
              key: $2
              scenario: $3
              phase: $4
              pattern: $5
              step: $6
              stylesheet: $7
              className: $8
            result = [
              that.selected.ids.scenario,
              'phases', that.selected.ids.phase,
              'patterns', that.selected.ids.pattern,
              'steps', that.selected.ids.step
            ]
          return unless that.selected.ids.service and that.selected.ids.key
          @loadStylesheet()
          resourcesUrl = "//#{env[this.selected.dev].api}/services/#{that.selected.ids.service}/keys/#{that.selected.ids.key}/resources/gears_navigation"
          $get resourcesUrl, (response) ->
            that.resource = response.resource
            return unless that.resource
            resource = that.resource.scenarios
            for key, index in result
              if index is result.length - 1
                filter = resource.filter (step) ->
                  return step if step.id is key
                resource = filter[0]
              else
                resource = resource[key]
            that.selected.type = resource.type
            that.selected.placement = resource.data.placement
            that.selected.data = resource.data
            that.selected.data = that.styleCompile(that.selected.data , 'step')
            for button in that.selected.data.button
              button = that.styleCompile(button , 'button')
            that.selected.formatStatus = true
            that.preview()
          , 'json'

        styleCompile: (data, type) ->
          styles = data.styles
          return data if not styles
          if type is 'step'
            animations = data.animations
            styles['border-width'] = styles['border-width'] + 'px'
            styles['font-size'] = styles['font-size'] + 'px'
          else if type is 'button'
            if styles.backgroundColorBegin
              start = styles.backgroundColorBegin
              end = styles['background-color']
              styles['background-image'] = "linear-gradient(to bottom, #{start}, #{end})" if start and end
            else
              styles['background-image'] = 'none'
          data

        preview: ->
          app.stepRender @selected
          app.parentVue.$broadcast 'preview-action', @selected
        clear: ->
          app.parentVue.$broadcast 'clear-action'
        done: ->
          this.selected.done = true
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
          event.preventDefault()
          p = xpath target
          c = cpath target
          app.parentVue.$broadcast 'element-selected',
            xpath: p
            cpath: c
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
          that.modal = selected.useModal and selected.type isnt 'toast'
        this.$on 'clear-action', ->
          that.modal = false
      data: ->
        modal: false

    Vue.component 'modal-layer', modalComponent
    this.modal = new Vue this.options

  stepRender: (selected) ->
    templates =
      balloon: [
        '<div class="spm-balloon">'
          '<button type="button" class="spm-balloon-close"></button>'
          '<div class="spm-balloon-arrow"></div>'
          '<h3 class="spm-balloon-title"></h3>'
          '<div class="spm-balloon-content"></div>'
          '<div class="spm-balloon-nav"></div>'
        '</div>'
      ].join ''
      toast: [
        '<div class="spm-toast">'
          '<button type="button" class="spm-toast-close"></button>'
          '<h3 class="spm-toast-title">{{{selected.data.title}}}</h3>'
          '<div class="spm-toast-content">{{{selected.data.content}}}</div>'
          '<div class="spm-toast-nav">'
            '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
          '</div>'
        '</div>'
      ].join ''
      dialog: [
        '<div class="spm-dialog">'
          '<div>'
            '<button type="button" class="spm-dialog-close"></button>'
            '<h3 class="spm-dialog-title">{{{selected.data.title}}}</h3>'
            '<div class="spm-dialog-content">{{{selected.data.content}}}</div>'
            '<div class="spm-dialog-nav">'
              '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'balloon-type-1': [
        '<div class="spm-balloon spm-balloon-type1">'
          '<div>'
            '<button type="button" class="spm-balloon-close"></button>'
            '<div class="spm-balloon-arrow"></div>'
            '<div class="spm-balloon-wrap">'
              '<div class="spm-navigation-image"></div>'
              '<div class="spm-balloon-inner">'
                '<h3 class="spm-balloon-title"></h3>'
                '<div class="spm-balloon-content"></div>'
              '</div>'
            '</div>'
            '<div class="spm-balloon-nav">'
              '<div></div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'balloon-type-2': [
        '<div class="spm-balloon spm-balloon-type2">'
          '<div>'
            '<button type="button" class="spm-balloon-close"></button>'
            '<div class="spm-balloon-arrow"></div>'
            '<div class="spm-balloon-wrap">'
              '<div class="spm-navigation-image"></div>'
              '<div class="spm-balloon-inner">'
                '<h3 class="spm-balloon-title"></h3>'
                '<div class="spm-balloon-content"></div>'
              '</div>'
            '</div>'
            '<div class="spm-balloon-nav">'
              '<div></div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'balloon-type-3': [
        '<div class="spm-balloon spm-balloon-type3">'
          '<div>'
            '<button type="button" class="spm-balloon-close"></button>'
            '<div class="spm-balloon-arrow"></div>'
            '<div class="spm-balloon-wrap">'
              '<div class="spm-balloon-inner">'
                '<div class="spm-balloon-content"></div>'
              '</div>'
              '<div class="spm-balloon-nav"></div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'toast-type-1': [
        '<div class="spm-toast-type1 spm-toast">'
          '<div :style="selected.data.styles">'
            '<button type="button" class="spm-toast-close"></button>'
            '<h3 class="spm-toast-title">{{{selected.data.title}}}</h3>'
            '<div class="spm-toast-content">{{{selected.data.content}}}</div>'
            '<div class="spm-toast-nav">'
              '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'toast-type-2': [
        '<div class="spm-toast-type2 spm-toast">'
          '<div :style="selected.data.styles">'
            '<button type="button" class="spm-toast-close"></button>'
            '<div class="spm-toast-wrap">'
              '<div class="spm-navigation-image">{{{selected.data.contentImage}}}</div>'
              '<div class="spm-toast-inner">'
                '<h3 class="spm-toast-title">{{{selected.data.title}}}</h3>'
                '<div class="spm-toast-content">{{{selected.data.content}}}</div>'
              '</div>'
            '</div>'
            '<div class="spm-toast-nav">'
              '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'toast-type-3': [
        '<div class="spm-toast-type3 spm-toast">'
          '<div :style="selected.data.styles">'
            '<button type="button" class="spm-toast-close"></button>'
            '<div class="spm-toast-wrap">'
              '<div class="spm-toast-inner">'
                '<h3 class="spm-toast-title">{{{selected.data.title}}}</h3>'
                '<div class="spm-navigation-image">{{{selected.data.contentImage}}}</div>'
              '</div>'
            '</div>'
            '<div class="spm-toast-nav">'
              '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'toast-type-4': [
        '<div class="spm-toast-type4 spm-toast">'
          '<div :style="selected.data.styles">'
            '<div class="spm-toast-wrap">'
              '<div class="spm-toast-inner">'
                '<h3 class="spm-toast-title">{{{selected.data.title}}}</h3>'
                '<div class="spm-toast-content">{{{selected.data.content}}}</div>'
              '</div>'
            '</div>'
            '<div class="spm-toast-nav">'
              '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
            '</div>'
            '<button type="button" class="spm-toast-close"></button>'
          '</div>'
        '</div>'
      ].join ''
      'toast-type-5': [
        '<div class="spm-toast-type5 spm-toast">'
          '<div :style="selected.data.styles">'
            '<button type="button" class="spm-toast-close"></button>'
            '<div class="spm-toast-wrap">'
              '<div class="spm-toast-inner">'
                '<div class="spm-navigation-image">{{{selected.data.contentImage}}}</div>'
              '</div>'
            '</div>'
            '<div class="spm-toast-nav">'
              '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
            '</div>'
          '</div>'
        '</div> '
      ].join ''
      'toast-type-6': [
        '<div class="spm-toast-type6 spm-toast">'
          '<div :style="selected.data.styles">'
            '<button type="button" class="spm-toast-close"></button>'
            '<h3 class="spm-toast-title">{{{selected.data.title}}}</h3>'
            '<div class="spm-toast-wrap">'
              '<div class="spm-toast-inner">'
                '<div class="spm-toast-content">{{{selected.data.content}}}</div>'
              '</div>'
              '<div class="spm-toast-nav"></div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'toast-type-7': [
        '<div class="spm-toast-type7 spm-toast">'
          '<div :style="selected.data.styles">'
            '<button type="button" class="spm-toast-close"></button>'
            '<div class="spm-toast-wrap">'
              '<div class="spm-toast-inner">'
                '<div class="spm-navigation-image">{{{selected.data.contentImage}}}</div>'
              '</div>'
              '<div class="spm-toast-nav">'
                '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
              '</div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'dialog-type-1': [
        '<div class="spm-dialog spm-dialog-type1">'
          '<div :style="selected.data.styles">'
            '<button type="button" class="spm-dialog-close"></button>'
            '<div class="spm-dialog-wrap">'
              '<h3 class="spm-dialog-title">{{{selected.data.title}}}</h3>'
              '<div class="spm-navigation-image">{{{selected.data.contentImage}}}</div>'
              '<div class="spm-dialog-content">{{{selected.data.content}}}</div>'
              '<div class="spm-dialog-nav">'
                '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
              '</div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''
      'dialog-type-2': [
        '<div class="spm-dialog spm-dialog-type2">'
          '<div :style="selected.data.styles">'
            '<button type="button" class="spm-dialog-close" @click="destroy()"></button>'
            '<div class="spm-dialog-wrap">'
              '<div class="spm-navigation-image">{{{selected.data.contentImage}}}</div>'
              '<div class="spm-dialog-nav">'
                '<div v-for="button in selected.data.button" class="spm-{{selected.type}}-button" :style="button.styles">{{{button.label}}}</div>'
              '</div>'
            '</div>'
          '</div>'
        '</div>'
      ].join ''

    template = [
      '<div v-show="selected.type" v-el:container :style="selected.data.animations" class="spm-{{selected.type}} {{selected.data.customClass}} {{selected.placement}} {{selected.ids.className}} {{animation}}">'
        "#{templates[selected.data.guideType] || templates[selected.type]}"
      '</div>'
      '<div v-el:light v-show="selected.type === \'balloon\'" :style="styles.light" class="spm-navigation-navlayer"></div>'
    ].join ''
    template

    stepComponent = Vue.extend
      template: template
      ready: ->
        that = this
        window.styles = this.styles
        this.$on 'preview-action', (selected) ->
          that.render selected
        this.$on 'clear-action', ->
          that.selected.type = ''
      data: ->
        selected:
          type: ''
          placement: 'top'
        styles:
          step:
            left: 0
            top: 0
          light:
            left: 0
            top: 0
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
              #selectElement = document.evaluate(that.selected.xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
              selectElement = $(that.selected.cpath)[0]
              $addClass selectElement, 'spm-navigation-float spm-navigation-relative'
              selectSize = getSize selectElement
              $(that.$els.container).show()
              that.setSize()
              X = selectSize.left
              Y = selectSize.top
              H = selectSize.height
              W = selectSize.width
              h = that.size.height
              w = that.size.width
              console.log selectSize, that.size
              switch that.selected.placement
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
              that.selected.placement = ''
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
        editing: ->
          app.parentVue.$broadcast 'editing-action',
            title: this.title
            content: this.content
        destroy: ->
          app.parentVue.$broadcast 'clear-action'

    Vue.component 'step-layer', stepComponent

    this.step = new Vue this.options

timer = setInterval ->
  if window.Vue
    clearInterval timer
    app.init()
, 200
