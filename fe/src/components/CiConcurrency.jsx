import * as React from 'react'
import { ci } from '../api'
import { makeRunConcurrency } from '../ciConcurrencyComponent.js'

// The candidate page's concurrency panel and Cancel control
// (CI-CONCURRENCY-1): the component built against React, with the
// same-origin, session-authorized ci API. Its behaviour lives in
// ciConcurrencyComponent.js and ciConcurrency.js, which the tests drive.
export const RunConcurrency = makeRunConcurrency(React, { ci })
