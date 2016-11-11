// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <assert.h>

#include <vector>

#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/fidl/cpp/bindings/interface_ptr.h"

namespace maxwell {

// General implementation intended to cover InterfacePtr.
template <typename T>
T GetFidlType(T t) {
  return t;
}

// "Specialization" (overload) covering unique_ptr.
template <typename T>
T* GetFidlType(std::unique_ptr<T>* p) {
  return p->get();
}

// General implementation intended to cover Binding and StrongBinding.
template <typename FidlType, typename UniqueType = FidlType*>
UniqueType Identify(FidlType* binding) {
  return binding;
}

// "Specialization" (overload) covering InterfacePtr.
template <typename Interface, typename UniqueType = Interface*>
UniqueType Identify(fidl::InterfacePtr<Interface>* ip) {
  return ip->get();
}

// An extensible/derivable InterfacePtrSet/(Strong)BindingSet that contains a
// collection of objects of type T that contain FidlTypes (e.g. InterfacePtr,
// Binding, or StrongBinding). Elements are automatically removed from the
// collection and destroyed when their associated MessagePipe experiences a
// connection error. When the set is destroyed all of the MessagePipes will be
// closed.
//
// Unlike the Fidl library InterfacePtrSet and (Strong)BindingSet, this class
// does not prevent further mutations to the underlying Fidl type. For well-
// defined behavior, the Fidl types should not be modified after being added to
// the set.
//
// Template parameters:
// * FidlType - the Fidl type governing each element of the collection, e.g.
//  InterfacePtr, Binding, or StrongBinding
// * T - the element type of the collection
// * GetFidlType - a function that extracts the FidlType from an element of the
//  collection. Defaults to the identity function, which only works if T =
//  FidlType.
// * UniqueType - a type that uniquely identifies a FidlType in the collection.
//  For InterfacePtrs, this is a pointer to the interface. For bindings, this is
//  the pointer to the binding.
// * Identify - a function that derives a UniqueType from a FidlType. Defaults
//  behave as described at UniqueType.
template <typename FidlType,
          typename T = FidlType,
          FidlType* GetFidlType(T*) = GetFidlType,
          typename UniqueType = void*,
          UniqueType Identify(FidlType*) = Identify>
class BoundSet {
 public:
  typedef typename std::vector<T>::iterator iterator;
  BoundSet() {}
  virtual ~BoundSet() {}

  // |ptr| must be bound to a message pipe.
  template <typename... _Args>
  T* emplace(_Args&&... __args) {
    elements_.emplace_back(std::forward<_Args>(__args)...);
    T* const c = &elements_.back();
    FidlType* const m = GetFidlType(c);
    assert(m->is_bound());
    UniqueType const id = Identify(m);
    // Set the connection error handler for the newly added item to be a
    // function that will erase it from the vector.
    m->set_connection_error_handler([this, id] { OnConnectionError(id); });
    return c;
  }

  // Removes the element at the given iterator. This effectively closes the pipe
  // there if open, but it does not call OnConnectionError.
  iterator erase(iterator it) { return elements_.erase(it); }

  // Closes the MessagePipe associated with each of the items in this set and
  // clears the set. This does not call OnConnectionError for every interface in
  // the set.
  void clear() { elements_.clear(); }
  bool empty() const { return elements_.empty(); }
  size_t size() const { return elements_.size(); }

  iterator begin() { return elements_.begin(); }
  iterator end() { return elements_.end(); }

 protected:
  virtual void OnConnectionError(UniqueType id) {
    auto it = Find(id);
    assert(it != elements_.end());
    elements_.erase(it);
  }

 private:
  iterator Find(UniqueType id) {
    return std::find_if(elements_.begin(), elements_.end(), [this, id](T& e) {
      return Identify(GetFidlType(&e)) == id;
    });
  }

  std::vector<T> elements_;
};

// Convenience alias of BoundSet to handle InterfacePtr containers.
//
// Since InterfacePtr itself is a movable type, the thing that uniquely
// identifies the InterfacePtr we wish to erase is its Interface*.
template <typename Interface,
          typename T = fidl::InterfacePtr<Interface>,
          fidl::InterfacePtr<Interface>* GetFidlType(T*) = GetFidlType>
using BoundPtrSet =
    BoundSet<fidl::InterfacePtr<Interface>, T, GetFidlType, Interface*>;

// Convenience alias of BoundSet to handle non-movable FIDL types, like Bindings
// (and the mythical StrongBinding).
//
// Note that the default T here must be a unique_ptr rather than the FIDL type
// itself since these FIDL types are not movable.
template <typename FidlType,
          typename T = std::unique_ptr<FidlType>,
          FidlType* GetFidlType(T*) = GetFidlType>
using BoundNonMovableSet = BoundSet<FidlType, T, GetFidlType, FidlType*>;

// Convenience alias of BoundSet to handle Binding containers.
template <typename Interface,
          typename T = std::unique_ptr<fidl::Binding<Interface>>,
          fidl::Binding<Interface>* GetFidlType(T*) = GetFidlType>
using BindingSet = BoundNonMovableSet<fidl::Binding<Interface>, T, GetFidlType>;

}  // namespace maxwell
