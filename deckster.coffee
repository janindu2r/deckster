#THESE NEED TO MATCH THE CSS
_css_variables =
  selectors:
    deck: '.deckster-deck'
    card: '.deckster-card'
    card_title: '.deckster-card-title'
    controls: '.deckster-controls'
    drag_handle: '.deckster-drag-handle'
    expand_handle: '.deckster-expand-handle'
    collapse_handle: '.deckster-collapse-handle'
    card_jump_scroll: '.deckster-card-jump-scroll'
    deck_jump_scroll: '.deckster-deck-jump-scroll'
    remove_handle: '.deckster-remove-handle'
    removed_dropdown: '.deckster-removed-dropdown'
    removed_card_li: '.deckster-removed-card-li'
    removed_card_button: '.deckster-removed-card-button'
    add_card_to_bottom_button: '.deckster-add-card-to-bottom-button'
    card_content:'.content'
    placeholders: '.placeholders'
    droppable:'.droppable'

  selector_functions:
    card_expanded: (option)->'[data-expanded='+option+']'
    deck_expanded: (option) -> '[data-cards-expanded='+option+']'
  classes: {}
  dimensions: {}
  styleSheet: "deckster.css"

###
  Default Ajax options, some options are typically overwritten.
###
_ajax_default = 
  success: (data,status, response) ->
      console.log("Success: "+status)
  error: (response,status,exception) ->
      console.log("Status: "+status+" Error: "+exception)
  timeout: 3000
  type: 'GET'
  async: true

###
  Used to keep track of ajax requests. Typically stored as _ajax_requests[deckId][cardId] = $.ajax(...)
###
_ajax_requests = {}
_css_variables.classes[sym] = selector[1..] for sym, selector of _css_variables.selectors

# Jump scroll area
_scrollToView = ($el) ->
  offset = $el.offset()
  offset.top -= 20
  offset.left -= 20
  $('html, body').animate {
    scrollTop: offset.top
    scrollLeft: offset.left
  }

_nav_menu = null # Feel free to rename this if something else fits better
_nav_menu_options = {}

###
# Creates the Bootstrap-based Navigation menu/Jump Scroll bar/Scroll helper from HTML,
# applies config options, places it in the DOM tree and returns the new element
###
_create_nav_menu = () ->
    markup = """<div id="deckster-scroll-helper" class="btn-group">
          <div class="btn-group #{_css_variables.classes.card_jump_scroll}">
            <button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown">
              JC <!-- "jump [to] card" -->
              <span class="caret"></span>
            </button>
            <ul class="dropdown-menu pull-left">
            </ul>
          </div>
          <div class="btn-group #{_css_variables.classes.deck_jump_scroll}">
            <button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown">
                JD<!-- "jump [to] deck" -- not implemented -->
              <span class="caret"></span>
            </button>
            <ul class="dropdown-menu pull-left">
            </ul>
          </div>
        </div>
        """ # "stupid emacs
    button_dom = $ markup

    stay_in_view = _nav_menu_options["stay-in-view"]
    if stay_in_view? and not stay_in_view
        outer_el = document
        button_dom.css 'position', 'absolute'
    else
        outer_el = window # outer_el is what we're going to measure to place the button bar

    left = false
    x_pos =_nav_menu_options["x-position"]
    calculate_x = () ->
        if x_pos is "left"
            left = "5px"
        else if x_pos is "right"
            button_dom.css "right", "5px"
            button_dom.find("ul.dropdown-menu")
                .removeClass("pull-left")
                .addClass("pull-right")
        else if x_pos is "middle"
            bw = button_dom.find(_css_variables.selectors.deck_jump_scroll)
                    .width()
            left = ($(outer_el).width() - bw) / 2
        else
        if left
            button_dom.css "left", left

    y_pos = _nav_menu_options["y-position"]
    top = "5px"
    calculate_top = () ->
        if y_pos is "bottom"
            top = ($(outer_el).height() - button_dom.height()) - 5
            button_dom.addClass("dropup")
        else if y_pos is "middle"
            top = ($(outer_el).height() - button_dom.height()) / 2
        button_dom.css "top", top
     
    # Apply calculate functions once to get approximate positioning
    calculate_x()
    calculate_top()

    $("body").append button_dom

    # Re-calculate with button size known
    calculate_top()
    calculate_x()

    # This makes sure something relevant is returned
    button_dom

# Designed both for scrolling to a deck and scrolling to a card in any deck.
# Builds the list based on all elements present in the DOM that match
# the title-selector (e.g., '.deckster-deck [data-title]' for a card
# with a title
_create_jump_scroll = (target_ul_selector, title_selector) ->
    _nav_menu ?= _create_nav_menu()
    $item_title_ddl = $ target_ul_selector
    # Start fresh
    $item_title_ddl.children().remove()
    $title_items = $ title_selector
    if $title_items.length is 0
        return

    $title_items.each (index, item) ->
        title = $(item).data 'title'
        $nav_item = $  "<li><a href='#'>#{title}</a></li>"
        # Set up the click callback for the menu item
        $nav_item.on 'click', () ->
          _scrollToView $ item
        $item_title_ddl.append $nav_item

_create_jump_scroll_card = () ->
    # Collect all data-title cards from ALL DECKS on the pge
    _create_jump_scroll "#{_css_variables.selectors.card_jump_scroll} ul",
            '.deckster-deck [data-title]'

_create_jump_scroll_deck = () ->
    _create_jump_scroll "#{_css_variables.selectors.deck_jump_scroll} ul",
            '.deckster-deck[data-title]'

window.Deckster = (options) ->
  $deck = $(this)

  unless $deck.hasClass(_css_variables.classes.deck)
    return console.log 'Not a valid deck'

  # Options
  __default_options =
    draggable: true
    expandable: true
    url_enabled:true
    removable: true
    droppable: true

  options = $.extend {}, __default_options, options

  ### 
  # Modify an option setting (with the config_option key) based on the
  # presence and value of a corresponding data- attribute (data_attr)
  # on the Deck DOM element
  ###
  __set_option = (data_attr, config_option) ->
    option = $deck.data data_attr
    if option?
      options[config_option or data_attr] = option in [true, 'true']
    # if the data- attribute is not found, don't change the value

  __set_option 'draggable'
  __set_option 'expandable'
  __set_option 'removable'
  __set_option 'url-enabled', 'url_enabled'
  __set_option 'droppable'

  ###
     Init Dragging options
  ###   
  options.animate = options.animate ? {}
  options.animate.properties = options.animate.properties ? {}
  options.animate.options = options.animate.options ? {}

  ###
  # Nav menu options (global)
  ###

  $.extend(_nav_menu_options, options["scroll-helper"])

  ###
    Deckster Base 
   --- Deckster Base Variables
  ###
  __next_id = 1
  __deck = {}
  __cards_by_id = {}
  __card_data_by_id = {}
  __col_max = 0
  __row_max = 0

  __cards_needing_resolved_in_order = []
  __cards_needing_resolved_by_id = {}

  __dominate_card_data = undefined
  

  ###
    Registered callbacks events. 
  ###
  __events =
    card_added: 'card_added'
    inited: 'inited'
    card_expanded: 'card_expanded'
    card_collapsed: 'card_collapsed'
    
  __event_callbacks = {}

  # --- Deckster Base Functions
  _on = (event, callback) ->
    __event_callbacks[event] = [] unless __event_callbacks[event]?
    __event_callbacks[event].push callback

  _ajax = (options) ->
      options = $.extend(true,{},_ajax_default,options)
      $.ajax(options)

  _add_card = ($card, d) ->
    throw 'Card is too wide' if d.col_span > __col_max

    _force_card_to_position $card, d, {row: d.row, col: d.col}

    for callback in __event_callbacks[__events.card_added] || []
      break if callback($card, d) == false

  _force_card_to_position = ($card, d, p) ->
    throw 'Card expands out of bounds' if p.col + (d.col_span - 1) > __col_max
    _mark_card_as_resolved d
    __dominate_card_data = d
    _identify_problem_cards()
    __deck = {}

    _loop_through_spaces p.row, p.col, (p.row + (d.row_span - 1)), (p.col + (d.col_span - 1)), (p2) ->
      __deck[p2.row] = {} unless __deck[p2.row]?
      __deck[p2.row][p2.col] = d.id

    _resolve_cards()

  _mark_card_as_resolved = (d) ->
    if __cards_needing_resolved_in_order.length > 0
      i = $.inArray(d.id, __cards_needing_resolved_in_order)
      if i > -1
        __cards_needing_resolved_in_order.splice i, 1
        delete __cards_needing_resolved_by_id[d.id]

  _identify_problem_cards = () ->
    for row, cols of __deck
      for col, id of cols
        unless id == undefined || id == __dominate_card_data.id || __cards_needing_resolved_by_id[id]?
          __cards_needing_resolved_by_id[id] = true
          __cards_needing_resolved_in_order.push id 

  _loop_through_spaces = (row_start, col_start, row_end, col_end, callback) ->
    row_i = row_start
    while row_i <= row_end
      col_i = col_start
      while col_i <= col_end
        p =
          row: row_i
          col: col_i
        r_value = callback p
        return if r_value == false # gives the option to break the loop
        col_i++
      row_i++

  _resolve_cards = () ->
    while __cards_needing_resolved_in_order.length > 0
      id = __cards_needing_resolved_in_order[0]
      $card = __cards_by_id[id]
      d = __card_data_by_id[id]
      _resolve_card_position $card, d
      _mark_card_as_resolved d
      
  _resolve_card_position = ($card, d) ->
    row_i = 1
    while true # WARNING --- MUST BREAK LOOP
      __deck[row_i] = {} unless __deck[row_i]?
      col_i = 1
      while col_i <= (__col_max - d.col_span) + 1
        can_go_here = true

        # can the card start here
        _loop_through_spaces row_i, col_i, (row_i + (d.row_span - 1)), (col_i + (d.col_span - 1)), (p2) ->
          __deck[p2.row] = {} unless __deck[p2.row]?
          if __deck[p2.row][p2.col]
            can_go_here = false
            return false

        # if so, then put it here
        if can_go_here == true
          _loop_through_spaces row_i, col_i, (row_i + (d.row_span - 1)), (col_i + (d.col_span - 1)), (p2) ->
            __deck[p2.row] = {} unless __deck[p2.row]?
            __deck[p2.row][p2.col] = d.id
          return

        col_i++
      row_i++

  ###
    Used to transition cards to new positions on the deck. Typical scenario arises when a card is being dragged to a new position and adjacent cards need to be repositioned.
    Transition positions are looked up and cached locally.
  ###
  _apply_transition = ($card,d) ->
    rowStr = _css_variables.selectors.card+"[data-row=\""+d.row+"\"]"
    colStr = _css_variables.selectors.card+"[data-col=\""+d.col+"\"]"
    _css_variables.dimensions = _css_variables.dimensions || {}
    leftAnimate = _css_variables.dimensions[colStr]
    topAnimate = _css_variables.dimensions[rowStr]
    #Did we have this value saved?
    unless leftAnimate? and topAnimate?
      mysheet = null
      for sheet, index in document.styleSheets
        if _css_variables.styleSheet == sheet.href.split("/").pop()
          mysheet = sheet
          break

      if  mysheet == null
        $card.attr 'data-row', d.row
        $card.attr 'data-col', d.col
        $card.css 'opacity','1'
        return

      myrules = mysheet.cssRules ? mysheet.rules
      for rule,index in myrules
        if rule.selectorText == rowStr
          topAnimate = rule.style.top
          _css_variables.dimensions[rowStr] = topAnimate
        else if rule.selectorText == colStr 
          leftAnimate = rule.style.left
          _css_variables.dimensions[colStr] = leftAnimate

    options.animate.properties.top = topAnimate
    options.animate.properties.left = leftAnimate
    options.animate.options.duration?= "slow"
    options.animate.options.easing?= "swing"
    options.animate.options.always = () ->
      $card.attr 'data-row', d.row
      $card.attr 'data-col', d.col
      $card.css 'opacity','1'

    ###
    The animation becomes confusing and inaccurate when to many animations are attempted on the same card;Solution: Stop current and pending animations and start just this one.
    ###
    $card.stop(true,false).animate(options.animate.properties, options.animate.options) 

  _apply_deck = () ->
    row_max = 0
    applied_card_ids = {}
    isDragging = true
    for row, cols of __deck
      for col, id of cols
        unless applied_card_ids[id]?
          applied_card_ids[id] = true

          $card = __cards_by_id[id]
          __card_data_by_id[id].row = parseInt row
          __card_data_by_id[id].col = parseInt col
          d = __card_data_by_id[id]

          $card.attr 'data-card-id', id
          if isDragging and not $card.hasClass "draggable"
            _apply_transition($card,d) 
          else
            $card.attr 'data-row', d.row
            $card.attr 'data-col', d.col
          $card.attr 'data-row-span', d.row_span
          $card.attr 'data-col-span', d.col_span

          row_max_value = d.row + d.row_span - 1
          __row_max = row_max_value if row_max_value > __row_max

    $deck.attr 'data-row-max', row_max

  ###
  # Initially, cards will be hidden if the 'data-hidden' attribute is true, or
  #   if the deck's 'remove-empty' attribute is true, and
  #   there is no card content, and
  #   there is no 'data-url' attribute
  ###
  _should_remove_card_in_init = ($card, $deck) ->
    ($card.data('hidden') == true or 
      ($deck.data('remove-empty') == true and 
       !$card.find(_css_variables.selectors.card_content).text().trim() and 
       !$card.data('url')))

  init = ->
    __col_max = $deck.data 'col-max'
    # Add title to deck
    $deck_wrapper = $ "<div>"
    $deck.replaceWith($deck_wrapper)
    title = $deck.data("title") or "Deckster Deck"
    $title_div = $ "<div class=\"deckster-title\">#{title}</div>"
    $deck_wrapper.append $title_div, $deck

    cards = $deck.children(_css_variables.selectors.card)
    cards.each ->
      $card = $(this)

      if _should_remove_card_in_init($card, $deck)
        $card.remove()
      else
        d =
          id: __next_id++
          row: parseInt $card.attr 'data-row'
          col: parseInt $card.attr 'data-col'
          row_span: parseInt $card.attr 'data-row-span'
          col_span: parseInt $card.attr 'data-col-span'

        __cards_by_id[d.id] = $card
        __card_data_by_id[d.id] = d
        _add_card($card, d)

    _apply_deck()
    cards.append "<div class='#{_css_variables.classes.controls}'></div>"
    for callback in __event_callbacks[__events.inited] || []
      break if callback($deck) == false
    _create_jump_scroll_card 0xDCC0FFEEBAD
    _create_jump_scroll_deck 0xDEADBEEF


  # Deckster Drag
  if options['draggable'] && options['draggable'] == true
    __$active_drag_card = undefined
    __active_drag_card_drag_data = undefined

    _on __events.inited, ($deck) ->
      controls = "<a class='#{_css_variables.classes.drag_handle} control drag'></a>"
      $deck.find(_css_variables.selectors.controls).append controls

    _on __events.inited, ($deck) ->
      _bind_drag_controls(this)

    _bind_drag_controls = (deck) ->
      $deck.find(_css_variables.selectors.drag_handle).on "mousedown", (e) ->
        $drag_handle = $(this)
        __$active_drag_card = $drag_handle.parents(_css_variables.selectors.card)

        __$active_drag_card.addClass('draggable')
        __$active_drag_card.css 'z-index', 1000

        __active_drag_card_drag_data =
          height: __$active_drag_card.outerHeight()
          width: __$active_drag_card.outerWidth()
          pos_y: __$active_drag_card.offset().top + __$active_drag_card.outerHeight() - e.pageY
          pos_x: __$active_drag_card.offset().left + __$active_drag_card.outerWidth() - e.pageX

        __active_drag_card_drag_data['original_top'] = e.pageY + __active_drag_card_drag_data['pos_y'] - __active_drag_card_drag_data['height']
        __active_drag_card_drag_data['original_left'] = e.pageX + __active_drag_card_drag_data['pos_x'] - __active_drag_card_drag_data['width']

        e.preventDefault();

      $deck.on 'mousemove', (e) ->
        if __$active_drag_card?
          new_top = e.pageY + __active_drag_card_drag_data['pos_y'] - __active_drag_card_drag_data['height']
          new_left = e.pageX + __active_drag_card_drag_data['pos_x'] - __active_drag_card_drag_data['width']
          original_left = __active_drag_card_drag_data['original_left']
          original_top = __active_drag_card_drag_data['original_top']
          
          messages = []
          if new_top - original_top < -200
            __active_drag_card_drag_data['original_top'] = __active_drag_card_drag_data['original_top']-200
            _move_card(__$active_drag_card,"up")
            messages.push 'UP' 
          if new_top - original_top > 200  
            __active_drag_card_drag_data['original_top'] = __active_drag_card_drag_data['original_top']+200
            _move_card(__$active_drag_card,"down")
            messages.push 'DOWN' 
          if new_left - original_left < -300
            __active_drag_card_drag_data['original_left'] = __active_drag_card_drag_data['original_left']-300
            _move_card(__$active_drag_card,"left")
            messages.push 'LEFT' 
          if new_left - original_left > 300
            __active_drag_card_drag_data['original_left']  = __active_drag_card_drag_data['original_left']+300
            _move_card(__$active_drag_card,"right")
            messages.push 'RIGHT'
          console.log messages.join(' ') if messages.length > 0

          __$active_drag_card.offset { top: new_top, left: new_left }

      $deck.on 'mouseup', (e) ->
        if __$active_drag_card?
          __$active_drag_card.removeClass('draggable')
          __$active_drag_card.css 'top', ''
          __$active_drag_card.css 'left', ''
          __$active_drag_card.css 'z-index', ''

          __$active_drag_card = undefined
          __active_drag_card_drag_data = undefined


    _move_card = ($card, direction) ->
      id = $card.data('card-id')
      d = __card_data_by_id[id]
      switch direction
        when 'left' then _force_card_to_position $card, d, { row: d.row, col: d.col - 1}
        when 'right' then _force_card_to_position $card, d, { row: d.row, col: d.col + 1}
        when 'up' then _force_card_to_position $card, d, { row: d.row - 1, col: d.col}
        when 'down' then _force_card_to_position $card, d, { row: d.row + 1, col: d.col}
      _apply_deck()

  # Deckster Expand
  if options['expandable'] && options['expandable'] == true
    _on __events.inited, ($deck) ->
      controls = """
                 <a class='#{_css_variables.classes.expand_handle} control expand'></a>
                 <a class='#{_css_variables.classes.collapse_handle} control collapse' style='display:none;'></a>
                 """
      $deck.find(_css_variables.selectors.controls).append controls

      $deck.find(_css_variables.selectors.expand_handle).click ->
        _expand_on_click(this)

      $deck.find(_css_variables.selectors.collapse_handle).click ->
        _collapse_on_click(this)

    _expand_on_click = (element) ->
        $expand_handle = $(element)
        $card = $expand_handle.parents(_css_variables.selectors.card)
        id = parseInt $card.attr 'data-card-id'

        d = __card_data_by_id[id]

        console.log ['Expand <<<', $card, d, { row: d.row, col: d.col }]

        $card.attr 'data-original-col', d.col
        $card.attr 'data-original-row-span', d.row_span
        $card.attr 'data-original-col-span', d.col_span
       
        if $card.data("col-expand")?
           expandColTo = parseInt($card.data("col-expand")) 
           expandColTo = if expandColTo > __col_max  then __col_max else expandColTo
        expandColTo = if expandColTo? and expandColTo > 0 then expandColTo else d.col_span
        expandRowTo = parseInt($card.data("row-expand")) if $card.data("row-expand")? 
        expandRowTo = if expandRowTo? and expandRowTo > 0 then expandRowTo else d.row_span

        d['row_span'] = expandRowTo
        d['col'] = if (expandColTo-1)+d.col <= __col_max  then d.col else 1
        d['col_span'] = expandColTo

        if d.col_span == $card.data('original-col-span') and d.row_span == $card.data('original-row-span')
          return;
        console.log ['Expand >>>', $card, d, { row: d.row, col: d.col }]


        _force_card_to_position $card, d, { row: d.row, col: d.col }
        _apply_deck()

        $expand_handle.hide()
        $expand_handle.siblings(_css_variables.selectors.collapse_handle).show()
        for callback in __event_callbacks[__events.card_expanded] || []
          break if callback($deck,$card) == false
          
    _collapse_on_click = (element) ->
        $collapse_handle = $(element)
        $card = $collapse_handle.parents(_css_variables.selectors.card)
        id = parseInt $card.attr 'data-card-id'

        d = __card_data_by_id[id]
        d.col = parseInt $card.attr 'data-original-col'
        d.row_span = parseInt $card.attr 'data-original-row-span'
        d.col_span = parseInt $card.attr 'data-original-col-span'

        $card.attr 'data-original-col', ''
        $card.attr 'data-original-row-span', ''
        $card.attr 'data-original-col-span', ''

        _force_card_to_position $card, d, { row: d.row, col: d.col }
        _apply_deck()

        $collapse_handle.hide()
        $collapse_handle.siblings(_css_variables.selectors.expand_handle).show()
        _clean_up_deck()
        for callback in __event_callbacks[__events.card_collapsed] || []
          break if callback($deck,$card) == false

      _on __events.inited, ()->
        #Find all decks that don't have "data-cards-expanded=false"
        $(_css_variables.selectors.deck+":not("+_css_variables.selector_functions.deck_expanded(false)+")").each((index)->
          $deck = $(this);
          #Find all cards that don't have "data-expanded=false" and expand them
          $deck.find(_css_variables.selectors.card+":not("+_css_variables.selector_functions.card_expanded(false)+")").each((index)->
            $(this).find(_css_variables.selectors.expand_handle).trigger "click"
          )
        )
        
       _on __events.card_expanded, ($deck,$card) ->
        deckId = $deck.data("deck-id") ? 1
        cardId = $card.data("card-id")
        if options["card-actions"]? and options["card-actions"]["deck-"+deckId]? and options["card-actions"]["deck-"+deckId]["card-"+cardId]? 

         cardActions = options["card-actions"]["deck-"+deckId]["card-"+cardId]
         if cardActions["card-expanded"]?
           ajaxOptions = cardActions["card-expanded"]($card,$card.find(_css_variables.selectors.card_content))
           if ajaxOptions?
             ###
                Abort any requests that are currently on-going.
             ###
             if _ajax_requests[deckId] and _ajax_requests[deckId][cardId]
              _ajax_requests[deckId][cardId].abort()
              delete _ajax_requests[deckId][cardId]

             ###
                Send the ajax request after any card animation has finished (Typically when a card is expanded its size will be changed.) For example, trying to animate and load content into the card makes both operations laggy and detract from the user experience. 
             ###
             $card.queue().push(()->_ajax(ajaxOptions))

      _on __events.card_collapsed, ($deck,$card) ->
        deckId = $deck.data("deck-id") ? 1
        cardId = $card.data("card-id")
        if options["card-actions"]? and options["card-actions"]["deck-"+deckId]? and options["card-actions"]["deck-"+deckId]["card-"+cardId]? 

         cardActions = options["card-actions"]["deck-"+deckId]["card-"+cardId]
         if cardActions["card-collapsed"]?
           ajaxOptions = cardActions["card-collapsed"]($card,$card.find(_css_variables.selectors.card_content))
           if ajaxOptions?
            $card.queue().push(()->_ajax(ajaxOptions))

  ###
    Setting url_enabled to true allows ajax requests to run.
  ###
  if options['url_enabled'] == true
    _on __events.card_added, ($card,d) ->
      if $card.data("url")?
        ajax_options = 
          url: $card.data "url" 
          type: if $card.data("url-method")? then $card.data "url-method"  else "GET"
          context: $card
          success: (data,status,response) -> 
            if (!!data.trim()) # URL content is not empty
              $controls = this.find(_css_variables.selectors.controls).clone true
              $title = this.find(_css_variables.selectors.card_title)
              this.html ""
              this.append $title
              this.append $controls
              this.append '<div class="content">' + data + '</div>'
            else # Remove the card if url content is empty & div text content is empty
              divText = this.find(_css_variables.selectors.card_content).text()
              if (!divText.trim() and $deck.data('remove-empty') == true)
                _create_jump_scroll_card()
                this.remove()
                _remove_card_from_deck this

         deckId = $card.closest(_css_variables.selectors.deck).data("deck-id") ? 1
         cardId = d.id
         ###
          Keep track of requests incase we need to abort them.
         ###
         _ajax_requests[deckId] = _ajax_requests[deckId] || {}
         _ajax_requests[deckId][cardId] = _ajax(ajax_options)

  ###
    Droppable Helper Methods:
  ###
  _placeholder_div = ($card,_d,settings) ->
    width = $card.outerWidth()
    height = $card.outerHeight()
    $placeholder = 
    $("<div>")
    .addClass("placeholders")
    .addClass(_css_variables.selectors.card.substring(1))
    .attr("data-col",_d["col"])
    .attr("data-row",_d["row"])
    .attr("data-col-span",_d.col_span)
    .attr("data-row-span",_d.row_span)
    .css("background-color","rgb("+settings.r+","+settings.g+","+settings.b+")")
    .css("z-index",settings.zIndex)
    $card.closest(_css_variables.selectors.deck).append($placeholder)
    $placeholder.click( (action) ->
      _remove_old_position $card,__card_data_by_id[_d.id]
      $selectedCard = $(action.currentTarget)
      #$card.css("z-index",0)
      __card_data_by_id[_d.id] = _d
      _set_new_position $card,_d
      _apply_transition $card,_d 
      $card.find(_css_variables.selectors.droppable).trigger("click")
    )
    $placeholder.mouseenter( (action) ->
      $(this).data("prev-z-index",$(this).css("z-index"))      
      $(this).css("z-index",1000)
    )
    $placeholder.mouseleave( (action) ->
      $(this).css("z-index",$(this).data("prev-z-index"))
    )
    return $card

  _remove_old_position = ($card,d) ->
    row_end = d.row+d.row_span-1
    col_end = d.col+d.col_span-1

    for row_remove in [d.row..row_end]
      for col_remove in [d.col..col_end]
        delete __deck[row_remove][col_remove]       

    return true

  _set_new_position = ($card,d) ->
    row_end = d.row_span+d.row-1
    col_end = d.col_span+d.col-1

    #add new entry to grid
    for row_add in [d.row..row_end]
      if not(__deck[row_add])
        __deck[row_add] = {}
      for col_add in [d.col..col_end]
        __deck[row_add][col_add] = d.id

    if row_end > __row_max
      __row_max = row_end

    _clean_up_deck()

    return true    

  _clean_up_deck = ()->
    #Clean up empty rows
    row_subtractor = __row_max
    while row_subtractor > 0
      if $.isEmptyObject(__deck[row_subtractor])
        delete __deck[row_subtractor]
        if __row_max == row_subtractor
          __row_max -= 1
      row_subtractor -= 1  

  _fit_location = (row,col,d) ->
    row_end = d.row_span+row-1
    col_end = d.col_span+col-1

    if col_end > __col_max
      return false

    for row_test in [row..row_end]
      for col_test in [col..col_end]
        if __deck[row_test] and __deck[row_test][col_test] #these areas must be empty
          return false # if not return false; we can't use spot.

    return true

  _add_placeholders = ($card,d)->
    zIndex = 1
    r = 0
    g = 25
    b = 50
    for row in [1..(__row_max+1)] #search over all rows, including last.
      for col in [1..__col_max] #search over all columns.
        if _fit_location(row,col,d)

          new_d = 
            "id": d.id
            "row": row
            "col":col
            "row_span":d.row_span
            "col_span":d.col_span
          console.log "new_d",new_d
          _placeholder_div($card,new_d,
            "zIndez":zIndex
            "r":r
            "g":g
            "b":b)

          zIndex += 1
          r = ((r+0)%200)
          g = ((g+50)%150)
          b = ((b+50)%250)

    return -1;

  ### 
    If set to true, cards can be picked up and dropped to a new spot on the deck without disturbing the positions of any other card.
    :Droppable Helper Methods End.
  ###
  if options.droppable == true
    _on __events.inited, ($card,d) ->
      $controls = $card.find(_css_variables.selectors.controls)
      $droppable = $("<a>D</a>").addClass(_css_variables.selectors.droppable.substring(1))
      $droppable.click( (element) ->  
        $drop_handle = $(element.currentTarget)
        if not $drop_handle.hasClass("cancel") 
          $card = $drop_handle.closest(_css_variables.selectors.card)
          $deck = $drop_handle.closest(_css_variables.selectors.deck)
          $deck.find(_css_variables.selectors.controls).children(":visible").addClass("hider").hide()
          $drop_handle.show()
          $drop_handle.html("C").addClass("cancel")
          id = parseInt($card.attr('data-card-id'))
          d = __card_data_by_id[id]
          _add_placeholders $card,d
        else
          $drop_handle.removeClass("cancel").html("D")
          $deck = $drop_handle.closest(_css_variables.selectors.deck)
          $deck.find(_css_variables.selectors.controls).children(".hider").show().removeClass("hider")
          $deck.find(_css_variables.selectors.placeholders).remove()
      )
      $controls.append($droppable)
          

  if true # Just in case we'll be needing some real check later on
      _on __events.card_added, ($card,d) ->
        title = $card.data "title"

        unless title? and !$card.find(_css_variables.selectors.card_title).text()
              return
        $title_div = $('<div>')
              .text(title)
              .addClass(_css_variables.classes.card_title)
        $card.prepend $title_div

  # Deckster Remove
  if options['removable'] && options['removable'] == true
    _on __events.inited, ($deck) ->
      controls = "<a class='#{_css_variables.classes.remove_handle} control remove'></a>"
      $deck.find(_css_variables.selectors.controls).append controls

      $deck.find(_css_variables.selectors.remove_handle).click ->
        _remove_on_click(this)

    _remove_on_click = (element) ->
        $remove_handle = $(element)
        $card = $remove_handle.parents(_css_variables.selectors.card)
        id = parseInt $card.attr 'data-card-id'
        titleText = $card.find(_css_variables.selectors.card_title).text()
        if !titleText
          # Display the first 15 characters of the content
          titleText = $card.find(_css_variables.selectors.card_content).text().substring(0,15)
        dropdown = $deck.parent().find(_css_variables.selectors.removed_dropdown)

        if dropdown.val()?
          # Add to dropdown menu
          dropdown.find('ul').append(_get_removed_card_li_tag(id, titleText)).appendTo(dropdown)
        else
          # Construct a new dropdown menu
          removed_dropdown_div = "
          <div class='btn-group #{_css_variables.classes.removed_dropdown}'>
            <button type='button' class='btn btn-default dropdown-toggle' data-toggle='dropdown'>
              Removed Cards
              <span class='caret'></span>
            </button>
            <ul class='dropdown-menu removed-cards pull-left'>
              " + _get_removed_card_li_tag(id, titleText) + " 
            </ul>
          </div>
          " 
          # Add the 'Removed Cards' dropdown to the page - right above the deck title bar
          $deck.parent().prepend(removed_dropdown_div)
          dropdown = $deck.parent().find(_css_variables.selectors.removed_dropdown)
          
        # Define onclick behavior for the 'Add' button in the 'Removed Cards' dropdown
        dropdown.find('#' + _css_variables.classes.removed_card_button + '-' + id).click ->
          _add_back_card(id)

        # Define onclick behavior for the 'Add to bottom' button in the 'Removed Cards' dropdown
        dropdown.find('#' + _css_variables.classes.add_card_to_bottom_button + '-' + id).click ->
          _add_back_card_to_bottom(id)

        # Remove this card from the deck
        _remove_card_from_deck $card
        $card.remove()
        _create_jump_scroll_card()
        _apply_deck()

    ###
    # Removes the card from the __deck variable so that it doesn't take up space once removed
    ###
    _remove_card_from_deck = ($card) ->
      cardId = parseInt($card.attr('data-card-id'))

      for row, cols of __deck
        for col, id of cols 
          if cardId == id
            delete __deck[row][col]

      return undefined

    ###
    # Returns the <li> tag for this card, to be shown within the 'Removed Card' dropdown.
    # It displays the card title (or the first 15 characters of the card content, if no title),
    #   and an 'Add' button.
    ###
    _get_removed_card_li_tag = (id, titleText) ->
      "<li id='#{_css_variables.classes.removed_card_li}-" + id + 
        "' class='#{_css_variables.classes.removed_card_li}'>" + titleText + 
        "<a id='#{_css_variables.classes.removed_card_button}-" + id + 
        "' ><img src='./public/images/plus.png' 
                 class='#{_css_variables.classes.removed_card_button}' ></a>" + 
        "<button id='#{_css_variables.classes.add_card_to_bottom_button}-" + id + 
        "' class='btn control add'>Add to bottom</button>" +
      "</li>"

    ###
    # This is the callback when the 'Add' button is clicked for the card from the 'Removed Cards' dropdown
    ###
    _add_back_card = (cardId) ->
      return unless cardId?
        
      $card = __cards_by_id[cardId] 
      d = __card_data_by_id[cardId]

      _add_back_card_helper(cardId, $card, d)
        
    ###
    # This is the callback when the 'Add to bottom ' button is clicked for the card from the 'Removed Cards' dropdown
    ###
    _add_back_card_to_bottom = (cardId) ->
      return unless cardId?
        
      console.log "__row_max: " + __row_max
      $card = __cards_by_id[cardId] 
      d = __card_data_by_id[cardId]

      # See if the card can fit in the last row, if not - add it back in the very last row, in the first column.
      can_fit_in_last_row = false

      for col in [1..__col_max] by 1
        if _does_fit_location(__row_max, col, d)
          can_fit_in_last_row = true
          console.log "fits in max row: __row_max, col: " + __row_max, col
          break
        else
          console.log "doesn't fit in max row: __row_max, col: " + __row_max, col

      if can_fit_in_last_row 
        d.row = __row_max
        d.col = col
      else
        d.row = __row_max + 1
        d.col = 1
      
      _add_back_card_helper(cardId, $card, d)
      
    _add_back_card_helper = (cardId, $card, d) ->
      # Add the card back to the deck
      $deck.append($card)
      _add_card $card, d
      _apply_deck()

      # Add back the control buttons click behavior
      $card.find(_css_variables.selectors.remove_handle).click ->
        _remove_on_click(this)
      $card.find(_css_variables.selectors.expand_handle).click ->
        _expand_on_click(this)
      $card.find(_css_variables.selectors.collapse_handle).click ->
        _collapse_on_click(this)
      _bind_drag_controls($card)

      # Add back to the jump card 
      _create_jump_scroll_card()

      # Remove from the "Removed Cards" dropdown
      $deck.parent().find('#' + _css_variables.classes.removed_card_li + '-' + cardId).remove()

      # Remove the "Removed Cards" dropdown if it doesn't have any cards
      dropdown = $deck.parent().find(_css_variables.selectors.removed_dropdown)
      dropdown.remove() if dropdown.find('ul').children().size() == 0
  
  _does_fit_location = (row,col,d) ->
    row_end = d.row_span+row
    col_end = d.col_span+col

    if col_end-1 > __col_max
      return false

    for row_test in [row..row_end]
      for col_test in [col..col_end]
        if __deck[row_test] and __deck[row_test][col_test] #these areas must be empty
          return false # if not return false; we can't use spot.

    return true

  # Deckster End

  init()

  deckster =
    deck: __deck
    on: _on
    events: __events

$ = jQuery
$.fn.deckster = window.Deckster


$("#deck1").deckster({
    animate: {
      properties: {
        opacity: ".5"
      },
      options: {
        duration: "slow"
      }
    }
  
    "card-actions":{
      "deck-1":
        "card-6":
          "card-expanded": ($card,$contentSection)->
            ajax_options =
              url:"./sampleSites/site6expand"
              type:"GET"
              success: (data,status, response)->
                ###
                  You'll want to replace the conte
                ###
                $cardContent = $contentSection.html(data)

                console.log("I've successfully replaced the content")
              error: ()->
                console.log("I've failed to repalce the content")
            
            return ajax_options
          "card-collapsed": ($card, $contentSection)->
            ajax_options =
              url:"./sampleSites/site6"
              type:"GET"
              success: (data,status, response)->
                $cardContent = $contentSection.html(data)

                console.log("I've successfully replaced the content")
              error: ()->
                console.log("I've failed to repalce the content")
            
            return ajax_options
    }

    "scroll-helper": {
        "x-position": "middle" # left | middle | right
        "y-position": "top" # bottom | middle | top
        "stay-in-view": true # true
    }
})
