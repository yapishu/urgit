import * as React from 'react'
import { ci } from '../api'
import { makeEventLog, makeSchedules } from '../ciEventsComponent.js'

// The CI tab's Events and Schedules panels (Delivery 1C): the components
// built against React, with the same-origin, session-authorized ci API.
// Their behaviour lives in ciEventsComponent.js, ciEventsView.js and
// ciEvents.js, which the tests drive.
export const EventLog = makeEventLog(React, { ci })
export const Schedules = makeSchedules(React, { ci })
